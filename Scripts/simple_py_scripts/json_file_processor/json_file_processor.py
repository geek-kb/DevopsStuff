import os
import sys
import json

def get_script_path():
    """Returns the directory of the current script."""
    return os.path.dirname(os.path.realpath(sys.argv[0]))

filename = f"{get_script_path()}/users.json"
print(f"filename: {filename}")

def load_data(filename):
    """Loads JSON data from a file.

    Args:
        filename (str): The path to the JSON file.

    Returns:
        list: A list of dictionaries containing user data.
    """
    with open(filename, "r") as f:
        return json.load(f)

list_of_dicts = load_data(filename)
print(list_of_dicts)

def filter_users(data, min_age):
    """Filters users whose age is greater than or equal to min_age.

    Args:
        data (list): A list of user dictionaries.
        min_age (int): The minimum age threshold.

    Returns:
        list: A filtered list of user dictionaries.
    """
    return [user for user in data if user['age'] >= min_age]

filtered_users = filter_users(list_of_dicts, 30)
print(filtered_users)

def transform_users(users):
    """Transforms a list of users into a dictionary format and saves it to a JSON file.

    Args:
        users (list): A list of filtered user dictionaries.

    Returns:
        None
    """
    newfile = f"{get_script_path()}/filtered_users.json"
    user_dict = {}

    for user in users:
        full_name = f"{user['first_name']}_{user['last_name']}"
        user_dict[full_name] = {
            "age": user["age"],
            "email": user["email"]
        }

    with open(newfile, "w") as output_file:
        json.dump(user_dict, output_file, indent=2)

    print(f"Filtered users saved to {newfile}")

transform_users(filtered_users)

