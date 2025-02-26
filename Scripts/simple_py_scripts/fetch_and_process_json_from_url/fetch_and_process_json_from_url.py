"""Module for fetching and processing user data from a JSON API.

This module demonstrates how to make HTTP requests to an API endpoint,
parse JSON responses, and extract specific user information.
"""

import requests, json

# API endpoint for user data
url = 'https://jsonplaceholder.typicode.com/users'

def fetch_and_process(url: str) -> None:
    """Fetch user data from API and display formatted user information.

    Makes an HTTP GET request to the specified URL, parses the JSON response,
    and prints formatted user details including name, username, and email.

    Args:
        url: The API endpoint URL to fetch user data from

    Raises:
        requests.exceptions.RequestException: If the HTTP request fails
        ValueError: If the response cannot be parsed as JSON

    Example:
        >>> fetch_and_process('https://jsonplaceholder.typicode.com/users')
        Name: Leanne Graham, Username: Bret, Email: Sincere@april.biz
        ...
    """
    try:
        # Make HTTP GET request
        response = requests.get(url)
        response.raise_for_status()  # Raise exception for bad status codes

        # Parse JSON response
        data = response.json()

        # Process and display each user's information
        for item in data:
            name = item['name']
            username = item['username']
            email = item['email']
            print(f"Name: {name}, Username: {username}, Email: {email}")

    except requests.exceptions.RequestException as e:
        print(f"HTTP Request failed: {e}")
    except ValueError as e:
        print(f"Error parsing JSON: {e}")

# Execute the function with the specified URL
if __name__ == "__main__":
    fetch_and_process(url)
