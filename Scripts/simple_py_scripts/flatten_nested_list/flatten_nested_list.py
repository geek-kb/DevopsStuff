"""Module for flattening nested lists into a single-level list.

This module provides functionality to convert a nested list structure
into a flat list by recursively processing all nested elements.
"""

# Example input list with multiple levels of nesting
input_list = [1, [2, [3, 4], 5], 6, [7 , [8, 9], 10]]

def flatten(input_list):
    """Recursively flatten a nested list into a single-level list.

    Args:
        input_list: A list that may contain nested lists at any depth

    Returns:
        A flat list containing all elements from the input list and its nested sublists

    Example:
        >>> nested = [1, [2, [3, 4], 5]]
        >>> flatten(nested)
        [1, 2, 3, 4, 5]
    """
    flat_list = []
    for i in input_list:
        if isinstance(i, list):
            # If element is a list, recursively flatten it
            flat_list.extend(flatten(i))
        else:
            # If element is not a list, add it directly
            flat_list.append(i)
    return(flat_list)

# Test the flatten function with our example input
print(flatten(input_list))  # Output: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
