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

app = Flask(__name__)
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

# Create a connection pool
def get_db_connection():
    try:
        connection = mysql.connector.connect(pool_name="mypool", pool_size=5, **MYSQL_CONFIG)
        return connection
    except mysql.connector.Error as err:
        logging.error(f"MySQL connection error: {err}")
        return None

# UI Route
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/debug-mysql', methods=['GET'])
def debug_mysql():
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

# Additional CRUD routes remain unchanged...

if __name__ == '__main__':
    from waitress import serve
    serve(app, host='0.0.0.0', port=8080)
