def memoize(func):
    """Decorator to memoize function results.

    Args:
        func: The function to memoize

    Returns:
        Wrapped function that uses a cache
    """
    cache = {}
    def wrapper(*args, **kwargs):
        """Internal wrapper function that manages the cache.

        Args:
            *args: Variable positional arguments
            **kwargs: Variable keyword arguments

        Returns:
            Cached result of the function call
        """
        key = args + tuple(sorted(kwargs.items()))
        if key not in cache:
            cache[key] = func(*args, **kwargs)
        print(cache)
        return cache[key]
    return wrapper

@memoize
def fib(n):
    """Calculate the nth Fibonacci number using memoization.

    Args:
        n: The index of the Fibonacci number to calculate

    Returns:
        The nth Fibonacci number
    """
    if n <= 1:
        return n
    else:
        return fib(n-1) + fib(n-2)

print(fib(10))
