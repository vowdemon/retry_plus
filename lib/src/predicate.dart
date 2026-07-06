/// Type that supports OR composition with the same kind of value.
abstract interface class OrComposable<Self extends Object> {
  /// Builds an OR composition.
  Self addOr(Self left, Self right);

  /// Combines this value with [other] using OR semantics.
  Self operator |(Self other);
}

/// Type that supports AND composition with the same kind of value.
abstract interface class AndComposable<Self extends Object> {
  /// Builds an AND composition.
  Self addAnd(Self left, Self right);

  /// Combines this value with [other] using AND semantics.
  Self operator &(Self other);
}

/// Type that supports NOT composition.
abstract interface class NotComposable<Self extends Object> {
  /// Builds a NOT composition.
  Self addNot(Self inner);

  /// Negates this value.
  Self operator ~();
}

/// Predicate type that supports OR, AND, and NOT composition.
abstract interface class BasePredicate<Self extends Object>
    implements OrComposable<Self>, AndComposable<Self>, NotComposable<Self> {}

/// Reusable operator implementation for composable predicates.
mixin PredicateOperators<Self extends Object> implements BasePredicate<Self> {
  @override
  Self operator |(Self other) => addOr(this as Self, other);

  @override
  Self operator &(Self other) => addAnd(this as Self, other);

  @override
  Self operator ~() => addNot(this as Self);
}
