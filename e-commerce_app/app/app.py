from flask import Flask, request, jsonify
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from functools import wraps
import logging
from flask_mysqldb import MySQL
import os

# Configure logging
log_file = "/var/log/app.log"
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s', handlers=[
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
app.config['MYSQL_HOST'] = os.getenv('MYSQL_HOST', 'localhost')
app.config['MYSQL_USER'] = os.getenv('MYSQL_USER', 'your_user')
app.config['MYSQL_PASSWORD'] = os.getenv('MYSQL_PASSWORD', 'your_password')
app.config['MYSQL_DB'] = os.getenv('MYSQL_DB', 'your_db')
mysql = MySQL(app)

# Authentication decorator
def authenticate(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        api_key = request.headers.get('Authorization')
        if api_key != '{}'.format(os.getenv('API_KEY')):
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return wrapper

# Error handling
@app.errorhandler(404)
def not_found(error):
    logging.error("Resource not found")
    return jsonify({"error": "Resource not found"}), 404

@app.errorhandler(400)
def bad_request(error):
    logging.error("Bad request")
    return jsonify({"error": "Bad request"}), 400

@app.route('/products', methods=['GET'])
@authenticate
@limiter.limit("10 per minute")
def get_products():
    cursor = mysql.connection.cursor()
    cursor.execute("SELECT * FROM products")
    products = cursor.fetchall()
    cursor.close()
    logging.info("Retrieved all products")
    return jsonify(products), 200

@app.route('/products/<int:id>', methods=['GET'])
@authenticate
@limiter.limit("10 per minute")
def get_product(id):
    cursor = mysql.connection.cursor()
    cursor.execute("SELECT * FROM products WHERE id = %s", (id,))
    product = cursor.fetchone()
    cursor.close()
    if not product:
        logging.warning(f"Product with id {id} not found")
        return jsonify({"error": "Product not found"}), 404
    logging.info(f"Retrieved product with id {id}")
    return jsonify(product), 200

@app.route('/products', methods=['POST'])
@authenticate
@limiter.limit("5 per minute")
def create_product():
    data = request.get_json()
    if not data or not data.get('name') or not data.get('price'):
        logging.error("Invalid input for product creation")
        return jsonify({"error": "Invalid input"}), 400
    cursor = mysql.connection.cursor()
    cursor.execute("INSERT INTO products (name, price) VALUES (%s, %s)", (data['name'], data['price']))
    mysql.connection.commit()
    product_id = cursor.lastrowid
    cursor.close()
    logging.info(f"Created product with id {product_id}")
    return jsonify({"id": product_id, "name": data['name'], "price": data['price']}), 201

@app.route('/products/<int:id>', methods=['PUT'])
@authenticate
@limiter.limit("5 per minute")
def update_product(id):
    data = request.get_json()
    if not data or not data.get('name') or not data.get('price'):
        logging.error("Invalid input for product update")
        return jsonify({"error": "Invalid input"}), 400
    cursor = mysql.connection.cursor()
    cursor.execute("UPDATE products SET name = %s, price = %s WHERE id = %s", (data['name'], data['price'], id))
    mysql.connection.commit()
    cursor.close()
    if cursor.rowcount == 0:
        logging.warning(f"Product with id {id} not found for update")
        return jsonify({"error": "Product not found"}), 404
    logging.info(f"Updated product with id {id}")
    return jsonify({"id": id, "name": data['name'], "price": data['price']}), 200

@app.route('/products/<int:id>', methods=['DELETE'])
@authenticate
@limiter.limit("5 per minute")
def delete_product(id):
    cursor = mysql.connection.cursor()
    cursor.execute("DELETE FROM products WHERE id = %s", (id,))
    mysql.connection.commit()
    cursor.close()
    if cursor.rowcount == 0:
        logging.warning(f"Product with id {id} not found for deletion")
        return jsonify({"error": "Product not found"}), 404
    logging.info(f"Deleted product with id {id}")
    return jsonify({"message": "Product deleted"}), 200

if __name__ == '__main__':
    from waitress import serve
    serve(app, host='0.0.0.0', port=8080)

# Unit tests
import unittest
import json

class ProductManagementAPITestCase(unittest.TestCase):

    def setUp(self):
        self.app = app.test_client()
        self.headers = {'Authorization': 'Bearer your_api_key'}

    def test_create_product(self):
        response = self.app.post('/products', json={"name": "Test Product", "price": 10.99}, headers=self.headers)
        self.assertEqual(response.status_code, 201)

    def test_get_products(self):
        self.app.post('/products', json={"name": "Test Product", "price": 10.99}, headers=self.headers)
        response = self.app.get('/products', headers=self.headers)
        self.assertEqual(response.status_code, 200)

    def test_get_product_not_found(self):
        response = self.app.get('/products/999', headers=self.headers)
        self.assertEqual(response.status_code, 404)

    def test_update_product(self):
        self.app.post('/products', json={"name": "Test Product", "price": 10.99}, headers=self.headers)
        response = self.app.put('/products/1', json={"name": "Updated Product", "price": 15.99}, headers=self.headers)
        self.assertEqual(response.status_code, 200)

    def test_delete_product(self):
        self.app.post('/products', json={"name": "Test Product", "price": 10.99}, headers=self.headers)
        response = self.app.delete('/products/1', headers=self.headers)
        self.assertEqual(response.status_code, 200)

if __name__ == '__main__':
    unittest.main()

