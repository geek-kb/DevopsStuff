from typing import List

def array_union(arr1: List[int], arr2: List[int]) -> List[int]:
    """
    Finds all unique elements from both arrays (union).
    
    :param arr1: First array
    :param arr2: Second array
    :return: List of all unique elements
    """
    return list(set(arr1) | set(arr2))

print(array_union([1, 2, 3], [3, 4, 5]))  # Output: [1, 2, 3, 4, 5]
