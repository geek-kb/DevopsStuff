from typing import List

def find_missing_number(arr: List[int], n: int) -> int:
    """
    Finds the missing number in an array containing 1 to n.
    
    :param arr: List of integers
    :param n: The upper bound of the expected sequence
    :return: The missing number
    """
    expected_sum = n * (n + 1) // 2
    actual_sum = sum(arr)
    return expected_sum - actual_sum

print(find_missing_number([1, 2, 4, 5, 6], 6))  # Output: 3
