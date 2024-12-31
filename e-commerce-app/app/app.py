from flask import Flask, request, jsonify, render_template
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from functools import wraps
import logging
import mysql.connector
import os
import time

# Configure logging
log_file = "/var/log/app.log"
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s', handlers=[
    logging.FileHandler(log_file),
    logging.StreamHandler()
])

# Initialize Flask app
app = Flask(__name__)

# Configure Flask-Limiter for rate limiting
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["100 per hour"]
)

# MySQL configuration
MYSQL_CONFIG = {
    'host': os.getenv('MYSQL_HOST'),
    'user': os.getenv('MYSQL_USER'),
    'password': os.getenv('MYSQL_PASSWORD'),
    'database': os.getenv('MYSQL_DB')
}
logging.info(f"MYSQL_HOST: {MYSQL_CONFIG['host']}")
logging.info(f"MYSQL_USER: {MYSQL_CONFIG['user']}")
logging.info(f"MYSQL_DB: {MYSQL_CONFIG['database']}")

# Create a database connection pool
def get_db_connection():
    """
    Establishes a connection to the MySQL database using a connection pool.

    Returns:
        connection: A connection object if successful, otherwise None.
    """
    try:
        connection = mysql.connector.connect(pool_name="mypool", pool_size=5, **MYSQL_CONFIG)
        return connection
    except mysql.connector.Error as err:
        logging.error(f"MySQL connection error: {err}")
        return None

# UI Route
@app.route('/')
def index():
    """
    Renders the main index page.

    Returns:
        A rendered HTML template for the index page.
    """
    return render_template('index.html')

@app.route('/debug-mysql', methods=['GET'])
def debug_mysql():
    """
    Tests the MySQL connection by executing a simple query.

    Returns:
        str: Success message if the query works, error message otherwise.
        int: HTTP status code (200 for success, 500 for failure).
    """
    try:
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            cursor.close()
            conn.close()
            return "MySQL connection is working", 200
        else:
            return "MySQL connection failed", 500
    except Exception as e:
        logging.error(f"MySQL connection failed: {e}")
        return f"MySQL connection failed: {e}", 500

# Authentication decorator
def authenticate(f):
    """
    A decorator to enforce API key-based authentication.

    Args:
        f (function): The function to wrap.

    Returns:
        function: The wrapped function.
    """
    @wraps(f)
    def wrapper(*args, **kwargs):
        api_key = request.headers.get('Authorization')
        expected_api_key = f"Bearer {os.getenv('API_KEY')}"
        if api_key != expected_api_key:
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return wrapper

@app.route('/products', methods=['GET'])
@authenticate
def get_products():
    """
    Fetches all products from the database.

    Returns:
        json: A list of products in JSON format.
        int: HTTP status code (200 for success, 500 for database connection issues).
    """
    try:
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM products")
            products = cursor.fetchall()
            cursor.close()
            conn.close()
            logging.info("Retrieved all products")
            return jsonify(products), 200
        else:
            return jsonify({"error": "Failed to connect to the database"}), 500
    except Exception as e:
        logging.error(f"MySQL query failed: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/products/<int:id>', methods=['GET'])
@authenticate
@limiter.limit("10 per minute")
def get_product(id):
    """
    Fetches a specific product by its ID.

    Args:
        id (int): The ID of the product to retrieve.

    Returns:
        json: The product details if found, an error message otherwise.
        int: HTTP status code (200 for success, 404 if not found, 500 for other issues).
    """
    try:
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM products WHERE id = %s", (id,))
            product = cursor.fetchone()
            cursor.close()
            conn.close()
            if not product:
                logging.warning(f"Product with id {id} not found")
                return jsonify({"error": "Product not found"}), 404
            logging.info(f"Retrieved product with id {id}")
            return jsonify(product), 200
        else:
            return jsonify({"error": "Failed to connect to the database"}), 500
    except Exception as e:
        logging.error(f"MySQL query failed: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/products', methods=['POST'])
@authenticate
@limiter.limit("5 per minute")
def create_product():
    """
    Creates a new product in the database.

    Request Body (JSON):
        - name (str): The name of the product.
        - price (float): The price of the product.

    Returns:
        json: The details of the newly created product.
        int: HTTP status code (201 for success, 400 for invalid input, 500 for database issues).
    """
    try:
        data = request.get_json()
        if not data or not data.get('name') or not data.get('price'):
            logging.error("Invalid input for product creation")
            return jsonify({"error": "Invalid input"}), 400
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            cursor.execute("INSERT INTO products (name, price) VALUES (%s, %s)", (data['name'], data['price']))
            conn.commit()
            product_id = cursor.lastrowid
            cursor.close()
            conn.close()
            logging.info(f"Created product with id {product_id}")
            return jsonify({"id": product_id, "name": data['name'], "price": data['price']}), 201
        else:
            return jsonify({"error": "Failed to connect to the database"}), 500
    except Exception as e:
        logging.error(f"MySQL query failed: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/products/<int:id>', methods=['PUT'])
@authenticate
@limiter.limit("5 per minute")
def update_product(id):
    """
    Updates an existing product in the database.

    Args:
        id (int): The ID of the product to update.

    Request Body (JSON):
        - name (str): The new name of the product.
        - price (float): The new price of the product.

    Returns:
        json: The details of the updated product.
        int: HTTP status code (200 for success, 400 for invalid input, 404 if product not found, 500 for other issues).
    """
    try:
        data = request.get_json()
        if not data or not data.get('name') or not data.get('price'):
            logging.error("Invalid input for product update")
            return jsonify({"error": "Invalid input"}), 400
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            cursor.execute(
                "UPDATE products SET name = %s, price = %s WHERE id = %s",
                (data['name'], data['price'], id)
            )
            conn.commit()
            if cursor.rowcount == 0:
                logging.warning(f"Product with id {id} not found for update")
                return jsonify({"error": "Product not found"}), 404
            cursor.close()
            conn.close()
            logging.info(f"Updated product with id {id}")
            return jsonify({"id": id, "name": data['name'], "price": data['price']}), 200
        else:
            return jsonify({"error": "Failed to connect to the database"}), 500
    except Exception as e:
        logging.error(f"MySQL query failed: {e}")
        return jsonify({"error": str(e)}), 500
    
@app.route('/products/<int:id>', methods=['DELETE'])
@authenticate
@limiter.limit("5 per minute")
def delete_product(id):
    """
    Deletes a product from the database.

    Args:
        id (int): The ID of the product to delete.

    Returns:
        json: A success message if the product is deleted, or an error message if not found.
        int: HTTP status code (200 for success, 404 if product not found, 500 for other issues).
    """
    try:
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM products WHERE id = %s", (id,))
            conn.commit()
            if cursor.rowcount == 0:
                logging.warning(f"Product with id {id} not found for deletion")
                return jsonify({"error": "Product not found"}), 404
            cursor.close()
            conn.close()
            logging.info(f"Deleted product with id {id}")
            return jsonify({"message": "Product deleted"}), 200
        else:
            return jsonify({"error": "Failed to connect to the database"}), 500
    except Exception as e:
        logging.error(f"MySQL query failed: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    """
    Starts the Flask application using Waitress as the WSGI server.
    """
    from waitress import serve
    serve(app, host='0.0.0.0', port=8080)
