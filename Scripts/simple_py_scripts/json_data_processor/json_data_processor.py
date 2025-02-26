import json
from typing import List, Dict

def load_data(filename):
    with open(filename, 'r') as f:
        return json.load(f)

def filter_records(data, min_age):
    return [record for record in data if record['age'] >= min_age]

def transform_records(records):
    result = {}
    for record in records:
        key = f"{record['first_name']}_{record['last_name']}"
        result[key] = {
            'age': record['age'],
            'email': record['email']
        }
    return result

def save_results(data, output_file):
    with open(output_file, 'w') as f:
        json.dump(data, f, indent=2)