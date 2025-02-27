# json_file_processor Documentation

<!-- BEGIN_PY_DOCS -->
## json_file_processor.py

### Functions

#### `get_script_path()`

Returns the directory of the current script.


#### `load_data(filename)`

Loads JSON data from a file.

Args:
    filename (str): The path to the JSON file.

Returns:
    list: A list of dictionaries containing user data.


#### `filter_users(data, min_age)`

Filters users whose age is greater than or equal to min_age.

Args:
    data (list): A list of user dictionaries.
    min_age (int): The minimum age threshold.

Returns:
    list: A filtered list of user dictionaries.


#### `transform_users(users)`

Transforms a list of users into a dictionary format and saves it to a JSON file.

Args:
    users (list): A list of filtered user dictionaries.

Returns:
    None


<!-- END_PY_DOCS -->