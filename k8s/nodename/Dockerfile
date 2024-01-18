FROM php:7.4-apache
COPY ./myenv.php /var/www/html/
RUN chmod 644 /var/www/html/myenv.php
RUN chown www-data:www-data /var/www/html/myenv.php
RUN chmod 755 /var/www/html
RUN echo "DirectoryIndex myenv.php" >> /etc/apache2/apache2.conf
