FROM --platform=amd64 mysql:latest as build

RUN mkdir -p /docker-entrypoint-initdb.d

COPY init.sql /docker-entrypoint-initdb.d/

RUN chmod -R 644 /docker-entrypoint-initdb.d && \
  chmod -R 755 /var/lib/mysql /var/lib/mysql-files /docker-entrypoint-initdb.d && \
  chown -R 999:999 /var/lib/mysql /var/lib/mysql-files /docker-entrypoint-initdb.d

ENV MYSQL_ROOT_PASSWORD=
ENV MYSQL_DATABASE=
ENV MYSQL_USER=

