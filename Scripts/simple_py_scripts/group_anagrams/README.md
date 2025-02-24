# Exercise: Group Anagrams

## Problem Statement

Write a Python function group_anagrams(words) that takes a list of strings and returns a list of lists, where each inner list contains words that are anagrams of each other.

Example:

```python
input_list = ["eat", "tea", "tan", "ate", "nat", "bat"]
```

Possible output:

```
[
  ["eat", "tea", "ate"],
  ["tan", "nat"],
  ["bat"]
]
```

Note: The order of the groups and the order of the words within each group does not matter.

Hints:

Consider using a dictionary to map a sorted version of the word (as a tuple or string) to all its anagrams.
Think about the time complexity of sorting each word, and whether this approach is efficient for larger inputs.
How would you handle edge cases such as an empty list or words with different cases?
Task:
Implement the function and test it with the provided example as well as other cases you come up with.
This exercise will help you practice using dictionaries, string manipulation, and list comprehensions in Python.
