"""Module for grouping anagrams from a list of words.

This module provides functionality to identify and group words that are anagrams
of each other (words that have the same letters in different orders).
"""

# Example list of words to group into anagrams
words = ["eat", "tea", "tan", "ate", "nat", "bat"]

def group_anagrams(words: list[str]) -> list[list[str]]:
    """Group words that are anagrams of each other.

    This function takes a list of words and returns a list of lists, where each inner
    list contains words that are anagrams of each other. Two words are anagrams if
    they contain exactly the same letters in a different order.

    Args:
        words: List of strings to be grouped

    Returns:
        List of lists, where each inner list contains anagrams of each other

    Example:
        >>> group_anagrams(["eat", "tea", "tan", "ate", "nat", "bat"])
        [["eat", "tea", "ate"], ["tan", "nat"], ["bat"]]
    """
    # Dictionary to store sorted word as key and list of anagrams as value
    anagrams = {}

    # Process each word in the input list
    for word in words:
        # Sort letters of the word to create a key
        sorted_word = "".join(sorted(word))

        # Add word to existing anagram group or create new group
        if sorted_word in anagrams:
            anagrams[sorted_word].append(word)
        else:
            anagrams[sorted_word] = [word]

    # Convert dictionary values to list and return
    return list(anagrams.values())

# Test the function with example words
if __name__ == "__main__":
    print(group_anagrams(words))  # Output: [['eat', 'tea', 'ate'], ['tan', 'nat'], ['bat']]
