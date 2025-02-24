# Exercise: Implement a Memoization Decorator

## Problem Statement

Create a decorator @memoize that caches the results of function calls.
When the decorated function is called with the same arguments, the cached result should be returned instead of recomputing it.
This technique is particularly useful for optimizing recursive functions.

### Task Details

#### Implement the Decorator

Write a decorator called memoize that uses a dictionary to store function results.
Use the function’s arguments as the key (consider using a tuple for positional arguments).
(Optional) Handle keyword arguments if you want to extend the exercise further.

#### Apply the Decorator

Use your @memoize decorator on a recursive implementation of the Fibonacci sequence.
Write a function fib(n) that computes the nth Fibonacci number recursively.

#### Test and Compare

Test your fib function with a value like n = 35 or higher.
(Optional) Compare the execution time with and without memoization to see the performance benefit.

#### Hints

Remember that decorators are functions that take a function as an argument and return a new function.
A simple way to cache results is to create an empty dictionary at the time of decoration.
Python’s built-in functools.lru_cache provides similar functionality, but implementing your own will deepen your understanding of decorators and caching.

### Example Skeleton

```python
def memoize(func):
    cache = {}
    def wrapper(*args, **kwargs):
        # Create a key from the function arguments
        key = args + tuple(sorted(kwargs.items()))
        if key not in cache:
            cache[key] = func(*args, **kwargs)
        return cache[key]
    return wrapper

@memoize
def fib(n):
    if n <= 1:
        return n
    return fib(n-1) + fib(n-2)

# Test the memoized Fibonacci function
print(fib(35))
```

This exercise will help you practice using decorators, understanding closures, and applying caching to optimize recursive functions.
