# memoization_decorator Documentation

<!-- BEGIN_PY_DOCS -->
## memoization_decorator.py

### Functions

#### `memoize(func)`

Decorator to memoize function results.

Args:
    func: The function to memoize

Returns:
    Wrapped function that uses a cache


#### `fib(n)`

Calculate the nth Fibonacci number using memoization.

Args:
    n: The index of the Fibonacci number to calculate

Returns:
    The nth Fibonacci number


#### `wrapper()`

Internal wrapper function that manages the cache.

Args:
    *args: Variable positional arguments
    **kwargs: Variable keyword arguments

Returns:
    Cached result of the function call


<!-- END_PY_DOCS -->