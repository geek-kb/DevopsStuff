import mysql.connector
import logging
import os
from flask import Flask, request, jsonify, render_template

app = Flask(__name__)

# Configure the logger
logging.basicConfig(
    level=logging.DEBUG,  # Set the logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
    format="{} [{}] {}".format("%(asctime)s", "%(levelname)s", "%(message)s"),  # Define the log format
    datefmt="%Y-%m-%d %H:%M:%S"  # Define the date/time format
)

# Create a logger instance
logger = logging.getLogger(__name__)

# Function to get data from MySQL database
def get_data_from_mysql(query):
    try:
        # Retrieve database connection details from environment variables
        host = os.environ.get("MYSQL_HOST")
        username = os.environ.get("MYSQL_APP_USER")
        password = os.environ.get("MYSQL_APP_PASSWORD")
        database = os.environ.get("MYSQL_DATABASE")

        # Establish a connection to the MySQL database
        connection = mysql.connector.connect(
            host=host,
            user=username,
            password=password,
            database=database
        )

        if connection.is_connected():
            cursor = connection.cursor(dictionary=True)

            # Execute the query
            cursor.execute(query)

            # Fetch all the rows from the result set
            data = cursor.fetchall()

            return data

    except mysql.connector.Error as error:
        logger.error("An error occurred: {}".format(error))
        print("Error:", error)

    finally:
        # Close the cursor and the connection
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

# Function to write data to MySQL database
def write_data_to_mysql(data):
    try:
        # Retrieve database connection details from environment variables
        host = os.environ.get("MYSQL_HOST")
        username = os.environ.get("MYSQL_APP_USER")
        password = os.environ.get("MYSQL_APP_PASSWORD")
        database = os.environ.get("MYSQL_DATABASE")
        table_name = os.environ.get("MYSQL_TABLE_NAME")

        # Establish a connection to the MySQL database
        connection = mysql.connector.connect(
            host=host,
            user=username,
            password=password,
            database=database
        )

        if connection.is_connected():
            logger.info("Database connected successfully.")
            cursor = connection.cursor()

            # Insert data into the database
            for entry in data:
                fname = entry['fname']
                lname = entry['lname']
                insert_query = "INSERT INTO {} (fname, lname) VALUES ('{}', '{}')".format(table_name, fname, lname)
                cursor.execute(insert_query)

            logger.info("Data inserted successfully.")

            # Commit the changes
            connection.commit()
            logger.info("Changes committed.")

            print("Data inserted successfully.")

    except mysql.connector.Error as error:
        logger.error("An error occurred: {}".format(error))
        print("Error:", error)
        return jsonify({"error": str(error)}), 500

    finally:
        # Close the cursor and the connection
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

# API endpoint to fetch data from MySQL
@app.route('/get_data', methods=['GET'])
def fetch_data():
    query = "SELECT fname as 'First Name',lname as 'Last Name' FROM {}".format(os.environ.get("MYSQL_TABLE_NAME"))
    data = get_data_from_mysql(query)
    return render_template('data_table.html', data=data)
    #return jsonify(data)

# API endpoint to write data to MySQL
@app.route('/write_data', methods=['POST'])
def insert_data():
    try:
        data = request.get_json()
        logger.info("Data received: {}".format(data))
        print(data)
        write_data_to_mysql(data)
        return jsonify({"message": "Data inserted successfully."})
    except Exception as e:
        return jsonify({"error": str(e)})

# Route to display the HTML form
@app.route('/', methods=['GET'])
def index():
    return render_template('form.html')

# Route to handle form submission
@app.route('/submit', methods=['POST'])
def submit():
    # Get user input from the form
    fname = request.form.get('fname')
    lname = request.form.get('lname')

    data = {
        "fname": fname,
        "lname": lname
    }
    logger.info("Data received: {}".format(data))
    try:
        write_data_to_mysql([data])
    except Exception as e:
        return jsonify({"error": str(e)})

    # Returns a response to the user if needed
    return "Form submitted successfully!"

if __name__ == '__main__':
    logger.info("Starting the application.")
    app.run(debug=True)