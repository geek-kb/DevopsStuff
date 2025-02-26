"""Module for processing JSON data with operations for loading, filtering, transforming and saving records.

This module provides utilities to work with JSON data containing person records with fields like
first_name, last_name, age, and email. It supports loading JSON files, filtering records by age,
transforming data structure, and saving results back to JSON format.
"""

import json
from typing import List, Dict

def load_data(filename: str) -> Dict:
    """Load JSON data from a file.

    Args:
        filename (str): Path to the JSON file to be loaded.

    Returns:
        Dict: Parsed JSON data as a dictionary.

    Raises:
        FileNotFoundError: If the specified file does not exist.
        json.JSONDecodeError: If the file contains invalid JSON.
    """
    with open(filename, 'r') as f:
        return json.load(f)

def filter_records(data: List[Dict], min_age: int) -> List[Dict]:
    """Filter records based on minimum age criteria.

    Args:
        data (List[Dict]): List of record dictionaries containing 'age' field.
        min_age (int): Minimum age threshold for filtering.

    Returns:
        List[Dict]: Filtered list of records where age is greater than or equal to min_age.

    Raises:
        KeyError: If any record in the input data is missing the 'age' field.
    """
    return [record for record in data if record['age'] >= min_age]

def transform_records(records: List[Dict]) -> Dict:
    """Transform records into a new format with name-based keys.

    Converts a list of records into a dictionary where keys are formatted as
    "first_name_last_name" and values contain age and email information.

    Args:
        records (List[Dict]): List of records containing 'first_name', 'last_name',
            'age', and 'email' fields.

    Returns:
        Dict: Transformed data with name-based keys and simplified record structure.

    Raises:
        KeyError: If any required fields are missing from the input records.
    """
    result = {}
    for record in records:
        key = f"{record['first_name']}_{record['last_name']}"
        result[key] = {
            'age': record['age'],
            'email': record['email']
        }
    return result

def save_results(data: Dict, output_file: str) -> None:
    """Save data to a JSON file with pretty printing.

    Args:
        data (Dict): Data to be saved as JSON.
        output_file (str): Path where the JSON file should be saved.

    Raises:
        IOError: If there are issues writing to the output file.
        TypeError: If the data cannot be serialized to JSON.
    """
    with open(output_file, 'w') as f:
        json.dump(data, f, indent=2)
