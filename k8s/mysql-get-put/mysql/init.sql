-- Create a new database
CREATE DATABASE IF NOT EXISTS getput;

-- Create a new user
CREATE USER '${TEMP_MYSQL_USER}'@'%' IDENTIFIED BY '${TEMP_MYSQL_PASSWORD}';
ALTER USER '${TEMP_MYSQL_USER}'@'%' IDENTIFIED WITH mysql_native_password BY '${TEMP_MYSQL_PASSWORD}';

-- Grant privileges to the new user for the new database
GRANT ALL PRIVILEGES ON ${TEMP_MYSQL_DATABASE}.* TO '${TEMP_MYSQL_USER}'@'%';

-- Flush privileges to apply changes
FLUSH PRIVILEGES;

-- Use the newly created database
USE ${TEMP_MYSQL_DATABASE};

-- Create a new table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fname VARCHAR(255) NOT NULL,
    lname VARCHAR(255) NOT NULL
);
