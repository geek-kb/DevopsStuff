FROM mysql:latest
RUN GENERATED_MYSQL_ROOT_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 15) && \
  mkdir -p /docker-entrypoint-initdb.d

ENV MYSQL_ROOT_PASSWORD=$GENERATED_MYSQL_ROOT_PASSWORD

COPY init.sql /docker-entrypoint-initdb.d/
