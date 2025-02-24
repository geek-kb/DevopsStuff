# Exercise: Fetch and Process JSON Data from a URL

## Problem Statement

Write a Python script that fetches JSON data from a given URL, parses it, and processes the data to output useful information. For example, you might fetch data from a public API and print specific fields from the JSON response.

## Task Details

### 1. Fetching Data

- **Make an HTTP GET request:**
  Use the `requests` library to send a GET request to a specified URL.
- **Check the response:**
  Ensure that the response is successful by checking the HTTP status code.

### 2. Parsing JSON

- **Parse the response:**
  Convert the JSON data from the response into a Python data structure using the `json()` method.
- **Handle errors:**
  Use exception handling to catch and manage any errors during the HTTP request or JSON parsing process.

### 3. Processing Data

- **Extract information:**
  Iterate over the JSON data and extract specific fields. For example, if the JSON data contains user information, print each user's name and email.
- **Display the output:**
  Format the output in a clear and readable manner.

## Example

Consider using the following URL: `https://jsonplaceholder.typicode.com/users`
This URL returns a JSON array of user objects. Your script should print each user's name and email address.

## Hints

- Install the `requests` library using `pip install requests` if it is not already installed.
- Use `response.raise_for_status()` to automatically raise an exception for HTTP errors.
- Use a loop to iterate over the parsed JSON data and extract the required fields.
- Use exception handling (`try`/`except`) to catch network or parsing errors.

# Example usage

url = "<https://jsonplaceholder.typicode.com/users>"
fetch_and_process(url)
