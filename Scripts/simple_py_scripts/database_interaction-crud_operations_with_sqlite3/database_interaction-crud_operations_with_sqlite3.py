import sqlite3

def create_and_populate_db() -> None:
    """Creates a SQLite database, adds data, and queries it."""
    connection = sqlite3.connect('example.db')
    cursor = connection.cursor()

    cursor.execute('''CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)''')
    cursor.execute('INSERT INTO users (name) VALUES (?)', ('Alice',))
    connection.commit()

    cursor.execute('SELECT * FROM users')
    print(cursor.fetchall())

    connection.close()

create_and_populate_db()
