# Exercise: Implement a Logger Decorator with List Flattening

## Problem Statement

Create a decorator `@logger` that adds timestamp information to function calls.
The decorator should handle nested lists by flattening them and logging each element with a timestamp.
This technique is particularly useful for creating detailed logs of function executions with complex data structures.

## Task Details

### Implement the List Flattening Function

Write a recursive function `flatten` that takes a nested list and returns a flattened version of it. The function should:

- Handle any level of nesting
- Preserve the order of elements
- Return a single flat list

### Implement the Logger Decorator

Write a decorator called `logger` that:

- Adds timestamps to each argument
- Handles both simple arguments and nested lists
- Formats the output with consistent timestamps

### Apply the Decorator

Use your `@logger` decorator on a print function that joins the lines with newlines:

```python
@logger
def pt(text):
    print("\n".join(text))
```

## Example Usage

```python
pt("Hello", ["nested", ["list", "example"]])
```

Expected output (timestamps will vary):

```
24/02/25 12:34:56 Hello
24/02/25 12:34:56 nested
24/02/25 12:34:56 list
24/02/25 12:34:56 example
```

## Hints

- Remember that decorators wrap a function to extend its functionality
- The `datetime` module provides current time functionality
- List flattening using recursion is a common pattern
- Consider using `strftime()` for consistent timestamp formatting

This exercise will help you practice:

- Writing decorators
- Handling nested data structures
- Working with timestamps
- Recursive functions
