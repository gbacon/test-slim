# Typed fixture conversion metadata

`Test::Slim` does not use Perl reflection to guess Java parameter types. A fixture can declare the types that need conversion and the executor applies its per-session converter registry to method and constructor arguments and method results.

## Method arguments and results

Return metadata from `slim_method_signature` using the dispatched Perl method name:

```perl
sub slim_method_signature {
  my ($self, $method) = @_;
  return {
    parameters => ['java.lang.Integer[]', 'java.util.List<java.lang.Boolean>'],
    return => 'java.util.Collection<java.lang.Integer>',
  } if $method eq 'process_values';
}

sub process_values {
  my ($self, $integers, $flags) = @_;
  # $integers and $flags are array references containing converted values.
  return $integers;
}
```

Argument types supported for component conversion are registered scalar types, including `String`, `Boolean`/`java.lang.Boolean`, `boolean`, `Integer`/`java.lang.Integer`, `int`, `Long`/`java.lang.Long`, `long`, `Double`/`java.lang.Double`, `double`, `Character`/`java.lang.Character`, `char`, and `java.util.Date`. Type aliases are accepted for simple names; canonical Java names are preferred.

Supported sequence metadata:

- `T[]` for a one-dimensional typed array.
- `java.util.List<T>` or `List<T>`.
- `java.util.Collection<T>` or `Collection<T>`.

Only registered scalar converters may be used as `T`. Nested generic syntax, multidimensional array parsing, Set, Queue, and reflection-based concrete collection types are not supported.

## Constructor arguments

Use the same type names in `slim_constructor_signature`:

```perl
sub slim_constructor_signature {
  return { parameters => ['int[]', 'java.util.List<java.lang.String>'] };
}
```

The constructor signature uses positional arguments. If metadata is absent, constructor arguments keep their previous untyped behavior.

## Input and result format

Sequence input uses Java's simple comma-separated syntax. Brackets are optional; values are split on commas and trimmed. There is no quoting or escaping for commas. A blank whole input converts to null. Explicit `[]` converts to an empty array or collection. Blank elements follow their component converter: for example, a blank boxed Integer becomes null, a blank `int` becomes zero, and a blank String remains empty. Invalid values raise the scalar converter error through the usual SLiM exception result.

Typed arrays and typed List/Collection results use Java-style bracketed text such as `[1, 2, 3]`. `callAndAssign` returns that text to FitNesse while retaining the raw Perl array reference in the symbol table. Passing that exact symbol to another typed method preserves the same reference rather than parsing it again. Untyped `java.util.List` results keep their legacy nested SLiM list representation.

At the SLiM wire boundary, the string `null` and the null token share the same spelling. A null reference can be preserved internally through symbols, while an ordinary string containing `null` is not distinguishable after serialization.

The implementation is a fixture metadata feature that composes existing scalar converters. It does not add a protocol type or emulate Java reflection, overload selection, nested generic type inspection, or Java collection classes.
