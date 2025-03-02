import re

def regex_example() -> None:
    """Uses regex to find a phone number pattern in a string."""
    text = "My phone number is 123-456-7890."
    pattern = r"\d{3}-\d{3}-\d{4}"
    match = re.search(pattern, text)
    if match:
        print(match.group())

regex_example()
