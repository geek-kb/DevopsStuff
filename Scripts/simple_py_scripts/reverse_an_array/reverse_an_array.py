from typing import List

def reverse_array(arr: List[int]) -> List[int]:
    """
    Reverses the elements of the array.
    
    :param arr: List of integers
    :return: List with elements in reverse order
    """
    return arr[::-1]

print(reverse_array([1, 2, 3, 4]))  # Output: [4, 3, 2, 1]
