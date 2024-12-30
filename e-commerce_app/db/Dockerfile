FROM --platform=amd64 mysql:latest as build

RUN GENERATED_MYSQL_ROOT_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 15) && \
  mkdir -p /docker-entrypoint-initdb.d \
  mkdir -p /var/lib/data \
  chmod -R 755 /var/lib/data 

ENV MYSQL_ROOT_PASSWORD=$GENERATED_MYSQL_ROOT_PASSWORD

RUN mkdir /var/lib/data -p
RUN chmod -R 755 /var/lib/data

COPY init.sql /docker-entrypoint-initdb.d/