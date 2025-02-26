"""Module for tracking ISS location and astronauts in space.

This module provides functionality to:
1. Fetch current number and names of astronauts in space
2. Get real-time ISS (International Space Station) location coordinates
using the Open Notify API (http://open-notify.org/).
"""

import requests

# API endpoints for astronaut data and ISS location
astros_api_url = 'http://api.open-notify.org/astros.json'
iss_api_url = 'http://api.open-notify.org/iss-now.json'

def fetch_astronauts(astros_api_url: str) -> None:
    """Fetch and display information about current astronauts in space.

    Makes an HTTP GET request to the astronauts API endpoint and displays
    the total number of astronauts and their details.

    Args:
        astros_api_url: URL of the astronauts API endpoint

    Raises:
        requests.exceptions.RequestException: If the HTTP request fails
        ValueError: If the response contains invalid JSON data

    Example:
        >>> fetch_astronauts(astros_api_url)
        There are 7 people in space:
        - Astronaut Name: John Smith, Astronaut Craft: ISS
    """
    try:
        astros_reponse = requests.get(astros_api_url)
        astros_reponse.raise_for_status()

        data = astros_reponse.json()

        # Get total number of astronauts
        astros_num = data.get('number')
        print(f"There are {astros_num} people in space: ")

        # Display details for each astronaut
        astros_data = data.get('people')
        for astro in astros_data:
            craft = astro['craft']
            name = astro['name']
            print(f"- Astronaut Name: {name}, Astronaut Craft: {craft}")

    except requests.exceptions.RequestException as e:
        print(f"HTTP request failed: {e}")
    except ValueError as e:
        print(f"Wrong value: {e}")


def get_iss_location(iss_api_url: str) -> None:
    """Fetch and display current ISS location coordinates.

    Makes an HTTP GET request to the ISS location API endpoint and displays
    the current latitude and longitude of the International Space Station.

    Args:
        iss_api_url: URL of the ISS location API endpoint

    Raises:
        requests.exceptions.RequestException: If the HTTP request fails
        ValueError: If the response contains invalid JSON data

    Example:
        >>> get_iss_location(iss_api_url)
        The ISS is currently at latitude: 45.5123, longitude: -122.6789
    """
    try:
        iss_response = requests.get(iss_api_url)
        iss_response.raise_for_status()

        data = iss_response.json()

        # Extract and display ISS coordinates
        position = data.get('iss_position')
        longitude = position.get('longitude')
        latitude = position.get('latitude')
        print(f"The ISS is currently at latitude: {latitude}, longitude: {longitude}.")

    except requests.exceptions.RequestException as e:
        print(f"HTTP request failed: {e}")
    except ValueError as e:
        print(f"Wrong value: {e}")

def main() -> None:
    """Execute main program functions.

    Fetches and displays both astronaut information and ISS location data.
    """
    fetch_astronauts(astros_api_url)
    print()  # Add blank line between outputs
    get_iss_location(iss_api_url)

if __name__ == "__main__":
    main()
