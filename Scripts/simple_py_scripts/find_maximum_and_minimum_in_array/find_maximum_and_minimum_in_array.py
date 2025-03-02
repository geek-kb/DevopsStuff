from typing import Tuple, List

def find_max_min(arr: List[int]) -> Tuple[int, int]:
    """
    Finds the maximum and minimum values in an array.
    
    :param arr: List of integers
    :return: A tuple containing (max_value, min_value)
    """
    return max(arr), min(arr)

print(find_max_min([3, 1, 4, 1, 5, 9]))  # Output: (9, 1)
