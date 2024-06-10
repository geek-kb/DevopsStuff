FROM python:3.8-slim-buster
WORKDIR /app
COPY app.py requirements.txt /app/
COPY templates /app/templates
RUN pip install --no-cache-dir -r requirements.txt
EXPOSE 5000
CMD ["python", "app.py"]
