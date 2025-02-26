# iss_tracker Documentation

<!-- BEGIN_PY_DOCS -->
## iss_tracker.py

Module for tracking ISS location and astronauts in space.

This module provides functionality to:
1. Fetch current number and names of astronauts in space
2. Get real-time ISS (International Space Station) location coordinates
using the Open Notify API (http://open-notify.org/).

### Functions

#### `fetch_astronauts(astros_api_url)`

Fetch and display information about current astronauts in space.

Args:
    astros_api_url: URL of the astronauts API endpoint

Raises:
    requests.exceptions.RequestException: If the HTTP request fails
    ValueError: If the response contains invalid JSON data


#### `get_iss_location(iss_api_url)`

Fetch and display current ISS location coordinates.

Args:
    iss_api_url: URL of the ISS location API endpoint

Raises:
    requests.exceptions.RequestException: If the HTTP request fails
    ValueError: If the response contains invalid JSON data


#### `main()`

Execute main program functions.


<!-- END_PY_DOCS -->