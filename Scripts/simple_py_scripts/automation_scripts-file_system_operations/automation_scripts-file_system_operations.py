import os
from pathlib import Path

def automate_file_operations() -> None:
    """Automates creating a directory and writing to a file."""
    os.makedirs('test_dir', exist_ok=True)
    file_path = Path('test_dir/test_file.txt')
    file_path.write_text('Hello, Automation!')
    print(file_path.read_text())

automate_file_operations()
