from typing import List

def merge_sorted_arrays(arr1: List[int], arr2: List[int]) -> List[int]:
    """
    Merges two sorted arrays into a single sorted array.
    
    :param arr1: First sorted array
    :param arr2: Second sorted array
    :return: Merged and sorted array
    """
    merged = []
    i, j = 0, 0

    while i < len(arr1) and j < len(arr2):
        if arr1[i] < arr2[j]:
            merged.append(arr1[i])
            i += 1
        else:
            merged.append(arr2[j])
            j += 1

    merged.extend(arr1[i:])
    merged.extend(arr2[j:])
    return merged

print(merge_sorted_arrays([1, 3, 5], [2, 4, 6]))  # Output: [1, 2, 3, 4, 5, 6]
