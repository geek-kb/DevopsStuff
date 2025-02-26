# json_data_processor Documentation

<!-- BEGIN_PY_DOCS -->
## json_data_processor.py

Module for processing JSON data with operations for loading, filtering, transforming and saving records.

This module provides utilities to work with JSON data containing person records with fields like
first_name, last_name, age, and email. It supports loading JSON files, filtering records by age,
transforming data structure, and saving results back to JSON format.

### Functions

#### `load_data(filename)`

Load JSON data from a file.

Args:
    filename (str): Path to the JSON file to be loaded.

Returns:
    Dict: Parsed JSON data as a dictionary.

Raises:
    FileNotFoundError: If the specified file does not exist.
    json.JSONDecodeError: If the file contains invalid JSON.


#### `filter_records(data, min_age)`

Filter records based on minimum age criteria.

Args:
    data (List[Dict]): List of record dictionaries containing 'age' field.
    min_age (int): Minimum age threshold for filtering.

Returns:
    List[Dict]: Filtered list of records where age is greater than or equal to min_age.

Raises:
    KeyError: If any record in the input data is missing the 'age' field.


#### `transform_records(records)`

Transform records into a new format with name-based keys.

Args:
    records (List[Dict]): List of records containing 'first_name', 'last_name',
        'age', and 'email' fields.

Returns:
    Dict: Transformed data with name-based keys and simplified record structure.

Raises:
    KeyError: If any required fields are missing from the input records.


#### `save_results(data, output_file)`

Save data to a JSON file with pretty printing.

Args:
    data (Dict): Data to be saved as JSON.
    output_file (str): Path where the JSON file should be saved.

Raises:
    IOError: If there are issues writing to the output file.
    TypeError: If the data cannot be serialized to JSON.


<!-- END_PY_DOCS -->