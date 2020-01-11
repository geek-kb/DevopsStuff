FROM ubuntu:latest
RUN apt-get update -y && \
    apt-get install -y \
    python3 \
    python3-pip \
    iputils-ping \
    telnet \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . /app
RUN pip3 install -r requirements.txt
CMD [ "python3", "/app/pingpong.py"]
