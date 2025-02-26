"""Module for logging text and nested lists with timestamps.

This module provides functionality to:
1. Flatten nested lists into a single level
2. Log text and list items with timestamps using a decorator pattern
"""

from datetime import datetime

def flatten(lst: list) -> list:
    """Recursively flatten a nested list structure.

    Args:
        lst: A list that may contain other lists at any nesting level

    Returns:
        A flat list containing all elements from input list and its sublists

    Example:
        >>> flatten([1, [2, [3, 4]], 5])
        [1, 2, 3, 4, 5]
    """
    flat_list = []
    for element in lst:
        if isinstance(element, list):
            # Recursively flatten nested lists
            flat_list.extend(flatten(element))
        else:
            # Add non-list elements directly
            flat_list.append(element)
    return flat_list

def logger(func):
    """Decorator that adds timestamps to text and list items.

    Processes input arguments and prepends timestamps before passing to
    the wrapped function. Handles both direct text input and nested lists.

    Args:
        func: The function to be wrapped

    Returns:
        Wrapper function that processes inputs with timestamps

    Example:
        >>> @logger
        ... def print_text(text):
        ...     print(text)
        >>> print_text("Hello", ["World"])
        01/01/24 12:00:00 Hello
        01/01/24 12:00:00 World
    """
    def wrapper(*args):
        lines = []
        now = datetime.now()
        time_fmt = now.strftime('%d/%m/%y %H:%M:%S')

        # Process each argument
        for arg in args:
            if isinstance(arg, list):
                # Flatten and timestamp list items
                flattened = flatten(arg)
                for item in flattened:
                    log_line = f"{time_fmt} {item}"
                    lines.append(log_line)
            else:
                # Timestamp direct text input
                log_line = f"{time_fmt} {arg}"
                lines.append(log_line)
        return func(lines)
    return wrapper

@logger
def pt(text: list) -> None:
    """Print text with timestamps on separate lines.

    Args:
        text: List of strings with timestamps to print

    Example:
        >>> pt("Hello", ["World"])
        26/02/24 16:30:00 Hello
        26/02/24 16:30:00 World
    """
    print("\n".join(text))

# Example usage
if __name__ == "__main__":
    pt("Hello", ["nested", ["list", "example"]])
