CREATE DATABASE IF NOT EXISTS ${TEMP_MYSQL_DB_NAME};
USE ${TEMP_MYSQL_DB_NAME};
CREATE TABLE IF NOT EXISTS ${TEMP_MYSQL_DB_TABLE} (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
INSERT INTO ${TEMP_MYSQL_DB_TABLE} (name, price) VALUES
('Product A', 19.99),
('Product B', 29.99),
('Product C', 39.99);
ALTER USER '${TEMP_MYSQL_USER}'@'%' IDENTIFIED WITH 'caching_sha2_password' BY '${TEMP_MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${TEMP_MYSQL_DB_NAME}.* TO '${TEMP_MYSQL_USER}'@'%';
FLUSH PRIVILEGES;