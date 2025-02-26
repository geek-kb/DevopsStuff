import json
from typing import List, Dict

def load_data(filename: str) -> Dict:
    with open(filename, 'r') as f:
        return json.load(f)

def filter_records(data: List[Dict], min_age: int) -> List[Dict]:
    return [record for record in data if record['age'] >= min_age]

def transform_records(records: List[Dict]) -> Dict:
    result = {}
    for record in records:
        key = f"{record['first_name']}_{record['last_name']}"
        result[key] = {
            'age': record['age'],
            'email': record['email']
        }
    return result

def save_results(data: Dict, output_file: str) -> None:
    with open(output_file, 'w') as f:
        json.dump(data, f, indent=2)

