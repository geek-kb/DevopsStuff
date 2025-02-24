# Exercise: ISS Tracker

## Problem Statement

Write a Python script that fetches the current location of the International Space Station (ISS) and the number of astronauts currently in space using two public APIs:

- **ISS Location API:** `http://api.open-notify.org/iss-now.json`
- **Astronauts API:** `http://api.open-notify.org/astros.json`

Your script should:

- Make HTTP GET requests to both APIs.
- Parse the JSON responses.
- Extract and display the ISS's current latitude and longitude.
- Extract and display the total number of astronauts in space.
- List the names of the astronauts along with the spacecraft they are on.

## Task Details

### 1. Fetch ISS Location

- **Request:** Use the `requests` library to send a GET request to `http://api.open-notify.org/iss-now.json`.
- **Parse JSON:** Convert the JSON response into a Python dictionary.
- **Extract Data:** Retrieve the latitude and longitude from the `iss_position` field.
- **Output:** Display the ISS location in a formatted message.

### 2. Fetch Astronaut Information

- **Request:** Use the `requests` library to send a GET request to `http://api.open-notify.org/astros.json`.
- **Parse JSON:** Convert the JSON response into a Python dictionary.
- **Extract Data:**
  - Get the total number of people in space.
  - Iterate through the list of people to extract each astronaut's name and the spacecraft they're on.
- **Output:** Display the number of astronauts and list each one with their respective spacecraft.

### 3. Error Handling

- **Network Errors:** Use `try`/`except` blocks to catch and handle network-related errors.
- **HTTP Errors:** Use `response.raise_for_status()` to manage unsuccessful HTTP responses.
- **JSON Parsing:** Include error handling for potential issues during JSON decoding.

## Hints

Ensure you have the requests library installed (use pip install requests if necessary).
Use response.raise_for_status() immediately after your GET requests to catch HTTP errors.
Use appropriate error handling with try/except to manage network issues or JSON parsing errors.
Inspect the JSON structure from the API endpoints to confirm which keys to extract.

## Expected Output (sample)

````
The ISS is currently at latitude: 47.6062, longitude: -122.3321.

There are 7 people in space:
- Chris Cassidy on ISS
- Anatoly Ivanishin on ISS
- Ivan Vagner on ISS
- ...
```

This exercise will help you practice:

Making HTTP requests and handling responses using the requests library.
Parsing and processing JSON data.
Working with multiple API endpoints.
Implementing robust error handling for network operations.
