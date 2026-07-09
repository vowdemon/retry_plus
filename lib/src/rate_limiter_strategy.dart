import 'dart:async';
import 'dart:collection';

import 'cancellation.dart';
import 'exceptions.dart';
import 'pipeline.dart';
import 'retry_pipeline_context.dart';
import 'telemetry.dart';

/// Context supplied when acquiring a rate-limit lease.
final class RateLimitContext {
  /// Creates rate-limit acquisition metadata.
  const RateLimitContext({
    required this.pipelineContext,
  });

  /// Current pipeline execution context.
  final RetryPipelineContext<Object?> pipelineContext;
}

/// Lease returned by a [RateLimiter].
abstract class RateLimitLease {
  /// Creates a rate-limit lease.
  const RateLimitLease();

  /// Creates an acquired lease.
  factory RateLimitLease.acquired({
    Duration? retryAfter,
    FutureOr<void> Function()? onRelease,
  }) {
    return _CallbackRateLimitLease(
      isAcquired: true,
      retryAfter: retryAfter,
      onRelease: onRelease,
    );
  }

  /// Creates a rejected lease.
  factory RateLimitLease.rejected({Duration? retryAfter}) {
    return _CallbackRateLimitLease(
      isAcquired: false,
      retryAfter: retryAfter,
    );
  }

  /// Whether execution may proceed.
  bool get isAcquired;

  /// Duration after which retry may be useful, when known.
  Duration? get retryAfter;

  /// Releases the lease.
  FutureOr<void> release();
}

/// Public contract for rate-limiter implementations.
abstract class RateLimiter {
  /// Creates a rate limiter.
  const RateLimiter();

  /// Attempts to acquire a lease for [context].
  FutureOr<RateLimitLease> acquire(RateLimitContext context);
}

/// Metadata provided when a rate limiter rejects execution.
final class RateLimitRejectedContext {
  /// Creates rate-limit rejection metadata.
  const RateLimitRejectedContext({
    required this.pipelineContext,
    required this.error,
    this.retryAfter,
  });

  /// Current pipeline execution context.
  final RetryPipelineContext<Object?> pipelineContext;

  /// Rejection error.
  final RateLimitRejectedException error;

  /// Duration after which retry may be useful, when known.
  final Duration? retryAfter;
}

/// Pipeline strategy that guards execution with a [RateLimiter].
final class RateLimiterStrategy<T> extends RetryPipelineStrategy<T> {
  /// Creates a rate limiter strategy.
  const RateLimiterStrategy(
    this.limiter, {
    super.name,
    this.onRejected,
  });

  /// Limiter used to acquire leases.
  final RateLimiter limiter;

  /// Hook invoked when the limiter rejects execution.
  final FutureOr<void> Function(RateLimitRejectedContext context)? onRejected;

  @override
  Future<T> execute(
    RetryPipelineContext<T> context,
    Future<T> Function() next,
  ) async {
    final lease = await limiter.acquire(
      RateLimitContext(pipelineContext: context),
    );
    context.throwIfCancelled();
    if (!lease.isAcquired) {
      final error = RateLimitRejectedException(retryAfter: lease.retryAfter);
      final rejectionContext = RateLimitRejectedContext(
        pipelineContext: context,
        error: error,
        retryAfter: lease.retryAfter,
      );
      await context.telemetry?.emit<T>(
        type: TelemetryEventType.rateLimiterRejected,
        strategyName: name,
        error: error,
        attributes: {
          if (lease.retryAfter != null) 'retryAfter': lease.retryAfter,
        },
      );
      await onRejected?.call(rejectionContext);
      throw error;
    }

    try {
      return await next();
    } finally {
      await lease.release();
    }
  }
}

/// FIFO concurrency limiter.
final class ConcurrencyLimiter implements RateLimiter {
  /// Creates a concurrency limiter.
  ConcurrencyLimiter({
    required this.permitLimit,
    this.queueLimit = 0,
  }) {
    if (permitLimit < 1) {
      throw ArgumentError.value(
        permitLimit,
        'permitLimit',
        'must be at least 1',
      );
    }
    if (queueLimit < 0) {
      throw ArgumentError.value(
        queueLimit,
        'queueLimit',
        'must not be negative',
      );
    }
    _availablePermits = permitLimit;
  }

  /// Maximum number of concurrent acquired leases.
  final int permitLimit;

  /// Maximum number of queued acquisitions.
  final int queueLimit;

  late int _availablePermits;
  final _queue = Queue<_QueuedPermit>();

  @override
  Future<RateLimitLease> acquire(RateLimitContext context) async {
    context.pipelineContext.throwIfCancelled();
    if (_availablePermits > 0) {
      _availablePermits--;
      return _ConcurrencyLease(this);
    }
    if (_queue.length >= queueLimit) {
      return RateLimitLease.rejected();
    }

    final queued = _QueuedPermit(context);
    _queue.addLast(queued);
    final lease = await queued.completer.future;
    context.pipelineContext.throwIfCancelled();
    return lease;
  }

  void _release() {
    while (_queue.isNotEmpty) {
      final queued = _queue.removeFirst();
      if (queued.context.pipelineContext.isCancelled) {
        queued.completer.completeError(
          const RetryCancelledException('Rate-limit acquisition cancelled'),
        );
        continue;
      }
      queued.completer.complete(_ConcurrencyLease(this));
      return;
    }
    _availablePermits++;
  }
}

/// Token bucket limiter with lazy, clock-driven refill.
final class TokenBucketLimiter implements RateLimiter {
  /// Creates a token bucket limiter.
  TokenBucketLimiter({
    required this.tokenLimit,
    required this.tokensPerPeriod,
    required this.refillPeriod,
    int? initialTokens,
  }) : _tokens = initialTokens ?? tokenLimit {
    _checkPositiveInt(tokenLimit, 'tokenLimit');
    _checkPositiveInt(tokensPerPeriod, 'tokensPerPeriod');
    _checkPositiveDuration(refillPeriod, 'refillPeriod');
    if (_tokens < 0 || _tokens > tokenLimit) {
      throw ArgumentError.value(
        initialTokens,
        'initialTokens',
        'must be between 0 and tokenLimit',
      );
    }
  }

  /// Maximum number of tokens the bucket can hold.
  final int tokenLimit;

  /// Tokens added for every [refillPeriod].
  final int tokensPerPeriod;

  /// Period used to refill tokens.
  final Duration refillPeriod;

  int _tokens;
  DateTime? _lastRefillAt;

  @override
  RateLimitLease acquire(RateLimitContext context) {
    final now = context.pipelineContext.now();
    _refill(now);
    if (_tokens > 0) {
      _tokens--;
      return RateLimitLease.acquired();
    }
    return RateLimitLease.rejected(retryAfter: _retryAfter(now));
  }

  void _refill(DateTime now) {
    final lastRefillAt = _lastRefillAt;
    if (lastRefillAt == null) {
      _lastRefillAt = now;
      return;
    }
    final elapsedMicros = now.difference(lastRefillAt).inMicroseconds;
    if (elapsedMicros < refillPeriod.inMicroseconds) {
      return;
    }
    final periods = elapsedMicros ~/ refillPeriod.inMicroseconds;
    _tokens = (_tokens + periods * tokensPerPeriod).clamp(0, tokenLimit);
    _lastRefillAt = lastRefillAt.add(refillPeriod * periods);
  }

  Duration _retryAfter(DateTime now) {
    final lastRefillAt = _lastRefillAt ?? now;
    final nextRefillAt = lastRefillAt.add(refillPeriod);
    final remaining = nextRefillAt.difference(now);
    return remaining > Duration.zero ? remaining : Duration.zero;
  }
}

/// Fixed window limiter with lazy window rollover.
final class FixedWindowLimiter implements RateLimiter {
  /// Creates a fixed window limiter.
  FixedWindowLimiter({
    required this.permitLimit,
    required this.window,
  }) {
    _checkPositiveInt(permitLimit, 'permitLimit');
    _checkPositiveDuration(window, 'window');
  }

  /// Maximum permits available in one window.
  final int permitLimit;

  /// Fixed window duration.
  final Duration window;

  DateTime? _windowStartedAt;
  var _usedPermits = 0;

  @override
  RateLimitLease acquire(RateLimitContext context) {
    final now = context.pipelineContext.now();
    _rollWindow(now);
    if (_usedPermits < permitLimit) {
      _usedPermits++;
      return RateLimitLease.acquired();
    }
    final windowStartedAt = _windowStartedAt ?? now;
    return RateLimitLease.rejected(
      retryAfter: windowStartedAt.add(window).difference(now),
    );
  }

  void _rollWindow(DateTime now) {
    final windowStartedAt = _windowStartedAt;
    if (windowStartedAt == null) {
      _windowStartedAt = now;
      return;
    }
    final elapsedMicros = now.difference(windowStartedAt).inMicroseconds;
    if (elapsedMicros < window.inMicroseconds) {
      return;
    }
    final windows = elapsedMicros ~/ window.inMicroseconds;
    _windowStartedAt = windowStartedAt.add(window * windows);
    _usedPermits = 0;
  }
}

/// Sliding window limiter backed by fixed-size time segments.
final class SlidingWindowLimiter implements RateLimiter {
  /// Creates a sliding window limiter.
  SlidingWindowLimiter({
    required this.permitLimit,
    required this.window,
    required this.segmentsPerWindow,
  }) : _segmentMicros = _computeSegmentMicros(window, segmentsPerWindow) {
    _checkPositiveInt(permitLimit, 'permitLimit');
  }

  /// Maximum permits available in the rolling window.
  final int permitLimit;

  /// Rolling window duration.
  final Duration window;

  /// Number of segments in [window].
  final int segmentsPerWindow;

  final int _segmentMicros;
  final _segments = <int, int>{};

  @override
  RateLimitLease acquire(RateLimitContext context) {
    final now = context.pipelineContext.now();
    final nowMicros = now.microsecondsSinceEpoch;
    _dropStaleSegments(nowMicros);
    final usedPermits =
        _segments.values.fold(0, (total, count) => total + count);
    if (usedPermits < permitLimit) {
      final segment = nowMicros ~/ _segmentMicros;
      _segments.update(segment, (count) => count + 1, ifAbsent: () => 1);
      return RateLimitLease.acquired();
    }
    return RateLimitLease.rejected(retryAfter: _retryAfter(nowMicros));
  }

  void _dropStaleSegments(int nowMicros) {
    final cutoffMicros = nowMicros - window.inMicroseconds;
    _segments.removeWhere((segment, _) {
      return segment * _segmentMicros <= cutoffMicros;
    });
  }

  Duration _retryAfter(int nowMicros) {
    if (_segments.isEmpty) {
      return Duration.zero;
    }
    final earliestSegmentStart =
        _segments.keys.reduce((left, right) => left < right ? left : right) *
            _segmentMicros;
    final availableAt = earliestSegmentStart + window.inMicroseconds;
    final remainingMicros = availableAt - nowMicros;
    return Duration(
      microseconds: remainingMicros > 0 ? remainingMicros : 0,
    );
  }
}

final class _CallbackRateLimitLease implements RateLimitLease {
  _CallbackRateLimitLease({
    required this.isAcquired,
    this.retryAfter,
    this.onRelease,
  });

  @override
  final bool isAcquired;

  @override
  final Duration? retryAfter;

  final FutureOr<void> Function()? onRelease;

  var _released = false;

  @override
  FutureOr<void> release() {
    if (_released) {
      return null;
    }
    _released = true;
    return onRelease?.call();
  }
}

final class _ConcurrencyLease implements RateLimitLease {
  _ConcurrencyLease(this._limiter);

  final ConcurrencyLimiter _limiter;

  var _released = false;

  @override
  bool get isAcquired => true;

  @override
  Duration? get retryAfter => null;

  @override
  void release() {
    if (_released) {
      return;
    }
    _released = true;
    _limiter._release();
  }
}

final class _QueuedPermit {
  _QueuedPermit(this.context);

  final RateLimitContext context;
  final completer = Completer<RateLimitLease>();
}

void _checkPositiveInt(int value, String name) {
  if (value < 1) {
    throw ArgumentError.value(value, name, 'must be at least 1');
  }
}

void _checkPositiveDuration(Duration value, String name) {
  if (value <= Duration.zero) {
    throw ArgumentError.value(value, name, 'must be positive');
  }
}

int _computeSegmentMicros(Duration window, int segmentsPerWindow) {
  _checkPositiveDuration(window, 'window');
  _checkPositiveInt(segmentsPerWindow, 'segmentsPerWindow');
  if (segmentsPerWindow > window.inMicroseconds) {
    throw ArgumentError.value(
      segmentsPerWindow,
      'segmentsPerWindow',
      'must not exceed the window microsecond length',
    );
  }
  if (window.inMicroseconds % segmentsPerWindow != 0) {
    throw ArgumentError.value(
      segmentsPerWindow,
      'segmentsPerWindow',
      'must divide the window evenly',
    );
  }
  return window.inMicroseconds ~/ segmentsPerWindow;
}
