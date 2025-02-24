# Exercise: Flatten a Nested List

## Problem Statement

Write a Python function flatten(nested_list) that takes a list which may contain nested lists of arbitrary depth and returns a new, flattened list with all the elements in the same order.

### Example

```python
input_list = [1, [2, [3, 4], 5], 6]
```

### Expected output

```python
[1, 2, 3, 4, 5, 6]
````

### Hints

**Recursion:**
Consider using recursion to handle the nested structure. If an element is a list, recursively flatten it before adding its elements to the result.

#### Type Checking

Use isinstance(element, list) to check if an element is a list.
Accumulation:
Think about how you'll accumulate the elements. You might find it helpful to use an accumulator list that you build up as you traverse the nested list.

## Task

Implement the function flatten(nested_list) and test it with the provided example as well as other cases (like an empty list, a list with no nested elements, or deeply nested lists). This exercise will help you practice recursion, type checking, and list manipulation in Python.
