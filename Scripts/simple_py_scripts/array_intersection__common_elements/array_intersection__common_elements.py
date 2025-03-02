from typing import List

def array_intersection(arr1: List[int], arr2: List[int]) -> List[int]:
    """
    Finds common elements between two arrays.
    
    :param arr1: First array
    :param arr2: Second array
    :return: List of common elements
    """
    return list(set(arr1) & set(arr2))

print(array_intersection([1, 2, 3, 4], [3, 4, 5, 6]))  # Output: [3, 4]
