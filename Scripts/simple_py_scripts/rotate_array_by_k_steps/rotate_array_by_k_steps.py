from typing import List

def rotate_array(arr: List[int], k: int) -> List[int]:
    """
    Rotates the array by k steps to the right.
    
    :param arr: List of integers
    :param k: Number of steps to rotate
    :return: Rotated array
    """
    k = k % len(arr)
    return arr[-k:] + arr[:-k]

print(rotate_array([1, 2, 3, 4, 5], 2))  # Output: [4, 5, 1, 2, 3]
