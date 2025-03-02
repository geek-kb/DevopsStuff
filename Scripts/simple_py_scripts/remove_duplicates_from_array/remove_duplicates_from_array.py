from typing import List

def remove_duplicates(arr: List[int]) -> List[int]:
    """
    Removes duplicate elements from the array while preserving order.
    
    :param arr: List of integers
    :return: List of unique elements
    """
    seen = set()
    return [x for x in arr if not (x in seen or seen.add(x))]

print(remove_duplicates([1, 2, 2, 3, 4, 4, 5]))  # Output: [1, 2, 3, 4, 5]
