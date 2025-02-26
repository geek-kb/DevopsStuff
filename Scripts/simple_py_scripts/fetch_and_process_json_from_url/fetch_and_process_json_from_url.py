import requests, json

url = 'https://jsonplaceholder.typicode.com/users'

def fetch_and_process(url):
    try:
        response = requests.get(url)
        response.raise_for_status()

        data = response.json()

        for item in data:
            name = item['name']
            username = item['username']
            email = item['email']
            print (f"Name: {name}, Username: {username}, Email: {email}")

    except requests.exceptions.RequestException as e:
        print(f"HTTP Request failed: {e}")
    except ValueError as e:
        print(f"Error parsing JSON: {e}")

fetch_and_process(url)
