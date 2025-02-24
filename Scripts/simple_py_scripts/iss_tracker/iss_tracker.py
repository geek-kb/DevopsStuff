import requests

astros_api_url = 'http://api.open-notify.org/astros.json'
iss_api_url = 'http://api.open-notify.org/iss-now.json'

def fetch_astronauts(astros_api_url):
    try:
        astros_reponse = requests.get(astros_api_url)
        astros_reponse.raise_for_status()

        data = astros_reponse.json()

        astros_num = data.get('number')
        print(f"Number of astronauts: {astros_num}")

        astros_data = data.get('people')
        for astro in astros_data:
            craft = astro['craft']
            name = astro['name']
            print(f"- Astronaut Name: {name}, Astronaut Craft: {craft}")

    except requests.exceptions.RequestException as e:
        print(f"HTTP request failed: {e}")
    except ValueError as e:
        print(f"Wrong value: {e}")


def get_iss_location(iss_api_url):
    try:
        iss_response = requests.get(iss_api_url)
        iss_response.raise_for_status()

        data = iss_response.json()

        position = data.get('iss_position')
        longitude = position.get('longitude')
        latitude = position.get('latitude')
        print(f"The ISS is currently at latitude: {latitude}, longitude: {longitude}.")

    except requests.exceptions.RequestException as e:
        print(f"HTTP request failed: {e}")
    except ValueError as e:
        print(f"Wrong value: {e}")

def main():
    fetch_astronauts(astros_api_url)
    print()
    get_iss_location(iss_api_url)

if __name__ == "__main__":
    main()
