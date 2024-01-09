-- Create a new database
CREATE DATABASE IF NOT EXISTS getput;

-- Create a new user
CREATE USER 'itai'@'%' IDENTIFIED BY 'Az123456';
ALTER USER 'itai'@'%' IDENTIFIED WITH mysql_native_password BY 'Az123456';

-- Grant privileges to the new user for the new database
GRANT ALL PRIVILEGES ON getput.* TO 'itai'@'%';

-- Flush privileges to apply changes
FLUSH PRIVILEGES;

-- Use the newly created database
USE getput;

-- Create a new table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fname VARCHAR(255) NOT NULL,
    lname VARCHAR(255) NOT NULL
);
