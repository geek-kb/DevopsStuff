-- Create the database
CREATE DATABASE IF NOT EXISTS product_db;

-- Use the newly created database
USE product_db;

-- Create the `products` table
CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO products (name, price) VALUES
('Product A', 19.99),
('Product B', 29.99),
('Product C', 39.99);

-- Grant permissions to a specific MySQL user
GRANT ALL PRIVILEGES ON product_db.* TO 'your_db_user'@'%' IDENTIFIED BY 'your_db_password';

-- Apply the permissions
FLUSH PRIVILEGES;

