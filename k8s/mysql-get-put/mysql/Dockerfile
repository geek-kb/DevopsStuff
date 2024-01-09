# Use the official MySQL Docker image as the base image
FROM mysql:latest

RUN GENERATED_MYSQL_ROOT_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 15)

# Set environment variables for MySQL root password
ENV MYSQL_ROOT_PASSWORD=$GENERATED_MYSQL_ROOT_PASSWORD

# Create a directory to store initialization scripts
RUN mkdir -p /docker-entrypoint-initdb.d

# Copy a custom initialization script to create a database, username, and password
COPY init.sql /docker-entrypoint-initdb.d/