import socket
import requests

def start_server() -> None:
    """Starts a simple socket server."""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(('localhost', 8080))
    server.listen(1)
    print('Server listening on port 8080')

def fetch_data_from_url(url: str) -> dict:
    """Fetches and returns JSON data from a given URL."""
    response = requests.get(url)
    return response.json()

print(fetch_data_from_url('https://jsonplaceholder.typicode.com/posts')[0])
