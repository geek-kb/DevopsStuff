import csv
import json
import xml.etree.ElementTree as ET

def write_text_file(filename: str, content: str) -> None:
    """Writes content to a text file."""
    with open(filename, 'w') as file:
        file.write(content)

def read_text_file(filename: str) -> str:
    """Reads content from a text file."""
    with open(filename, 'r') as file:
        return file.read()

def write_csv_file(filename: str, data: list) -> None:
    """Writes data to a CSV file."""
    with open(filename, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        for row in data:
            writer.writerow(row)

def parse_xml(xml_data: str) -> str:
    """Parses XML data and returns the text of the first item element."""
    root = ET.fromstring(xml_data)
    return root.find('item').text

def write_json_file(filename: str, data: dict) -> None:
    """Writes data to a JSON file."""
    with open(filename, 'w') as json_file:
        json.dump(data, json_file, indent=4)

def read_json_file(filename: str) -> dict:
    """Reads data from a JSON file and returns a dictionary."""
    with open(filename, 'r') as json_file:
        return json.load(json_file)

# Example usage:
write_text_file('example.txt', 'Hello, File Handling!')
print(read_text_file('example.txt'))

write_csv_file('example.csv', [['Name', 'Age'], ['Alice', 30]])

xml_data = """<data><item key="value">Content</item></data>"""
print(parse_xml(xml_data))

write_json_file('example.json', {'name': 'Alice', 'age': 30})
print(read_json_file('example.json'))
