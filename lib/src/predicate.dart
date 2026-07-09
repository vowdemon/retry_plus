import 'dart:async';

/// Predicate evaluated against a context value.
abstract class ContextPredicate<C, Self extends ContextPredicate<C, Self>> {
  /// Creates a context predicate.
  const ContextPredicate();

  /// Returns true when this predicate handles [context].
  FutureOr<bool> shouldHandle(C context);

  /// Wraps [shouldHandle] in the concrete predicate type.
  Self build(FutureOr<bool> Function(C context) shouldHandle);

  /// Builds an OR composition.
  Self or(Self left, Self right) {
    return build((context) async =>
        await left.shouldHandle(context) || await right.shouldHandle(context));
  }

  /// Builds an AND composition.
  Self and(Self left, Self right) {
    return build((context) async =>
        await left.shouldHandle(context) && await right.shouldHandle(context));
  }

  /// Builds a NOT composition.
  Self not(Self inner) {
    return build((context) async => !await inner.shouldHandle(context));
  }

  /// Combines this value with [other] using OR semantics.
  Self operator |(Self other) => or(this as Self, other);

  /// Combines this value with [other] using AND semantics.
  Self operator &(Self other) => and(this as Self, other);

  /// Negates this value.
  Self operator ~() => not(this as Self);
}
