def quicksort(arr: list) -> list:
    """Performs quicksort on the provided list."""
    if len(arr) <= 1:
        return arr
    pivot = arr[len(arr) // 2]
    left = [x for x in arr if x < pivot]
    middle = [x for x in arr if x == pivot]
    right = [x for x in arr if x > pivot]
    return quicksort(left) + middle + quicksort(right)

def binary_search(arr: list, target: int) -> int:
    """Performs binary search and returns the index of the target, or -1 if not found."""
    left, right = 0, len(arr) - 1
    while left <= right:
        mid = (left + right) // 2
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            left = mid + 1
        else:
            right = mid - 1
    return -1

print(quicksort([3, 6, 8, 10, 1, 2, 1]))
print(binary_search([1, 2, 3, 4, 5], 3))
