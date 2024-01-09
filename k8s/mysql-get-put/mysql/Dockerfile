FROM mysql:latest
RUN GENERATED_MYSQL_ROOT_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 15)
ENV MYSQL_ROOT_PASSWORD=$GENERATED_MYSQL_ROOT_PASSWORD
RUN mkdir -p /docker-entrypoint-initdb.d
COPY init.sql /docker-entrypoint-initdb.d/