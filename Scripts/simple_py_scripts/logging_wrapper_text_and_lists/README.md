# logging_wrapper_text_and_lists Documentation

<!-- BEGIN_PY_DOCS -->
## logging_wrapper_text_and_lists.py

Module for logging text and nested lists with timestamps.

This module provides functionality to:
1. Flatten nested lists into a single level
2. Log text and list items with timestamps using a decorator pattern

### Functions

#### `flatten(lst)`

Recursively flatten a nested list structure.

Args:
    lst: A list that may contain other lists at any nesting level

Returns:
    A flat list containing all elements from input list and its sublists


#### `logger(func)`

Decorator that adds timestamps to text and list items.

Args:
    func: The function to be wrapped

Returns:
    Wrapper function that processes inputs with timestamps


#### `pt(text)`

Print text with timestamps on separate lines.

Args:
    text: List of strings with timestamps to print


#### `wrapper()`


<!-- END_PY_DOCS -->