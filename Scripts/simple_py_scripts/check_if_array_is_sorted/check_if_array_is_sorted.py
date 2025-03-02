from typing import List

def is_sorted(arr: List[int]) -> bool:
    """
    Checks if the array is sorted in ascending order.
    
    :param arr: List of integers
    :return: True if the array is sorted, otherwise False
    """
    return arr == sorted(arr)

print(is_sorted([1, 2, 3, 4]))  # Output: True
print(is_sorted([4, 3, 2, 1]))  # Output: False
