from typing import List

def find_duplicates(arr: List[int]) -> List[int]:
    """
    Finds duplicate elements in the array.
    
    :param arr: List of integers
    :return: List of duplicate elements
    """
    seen = set()
    duplicates = set()
    for num in arr:
        if num in seen:
            duplicates.add(num)
        seen.add(num)
    return list(duplicates)

print(find_duplicates([1, 2, 2, 3, 4, 4, 5]))  # Output: [2, 4]
