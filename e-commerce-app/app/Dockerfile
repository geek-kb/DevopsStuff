FROM --platform=amd64 python:3.9-slim as build

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libffi-dev \
    default-libmysqlclient-dev \
    pkg-config \
    python3-waitress \
    && rm -rf /var/lib/apt/lists/*

# USER app
# Install Python dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy application code
COPY ./app.py /app/app.py
COPY ./templates /app/templates

# Expose port
EXPOSE 8080

# Run the application
CMD ["waitress-serve", "--host=0.0.0.0", "--port=8080", "app:app"]

