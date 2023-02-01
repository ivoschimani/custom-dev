FROM alpine:3.15

LABEL org.opencontainers.image.authors="ivo@schimani.de"

ARG LOCAL_USER_ID=1000
ARG LOCAL_GROUP_ID=1000

RUN apk update \
  && apk upgrade

# Create user
RUN mkdir -p /var/www && \
    adduser -D --home /var/www -u $LOCAL_USER_ID -g $LOCAL_GROUP_ID -s /bin/sh www-data -G www-data && \
    chown -R www-data:www-data /var/www

RUN mkdir -p /run/nginx

# Install nginx
# Create cachedir and fix permissions
RUN apk --no-cache --update add \
    nginx && \
    mkdir -p /var/cache/nginx && \
    mkdir -p /var/tmp/php && \
    mkdir -p /var/tmp/nginx && \
    chown -R www-data:www-data /var/cache/nginx && \
    chown -R www-data:www-data /var/lib/nginx && \
    chown -R www-data:www-data /var/tmp/nginx && \
    chown -R www-data:www-data /var/tmp/php

RUN apk --no-cache --update add tzdata php7 php7-fpm php7-pdo_mysql php7-json php7-iconv php7-openssl \
    php7-curl php7-ctype php7-zlib php7-xml php7-phar php7-intl php7-session php7-simplexml php7-soap \
    php7-fileinfo php7-dom php7-tokenizer php7-pdo php7-xmlreader php7-xmlwriter php7-mbstring php7-gd \
    php7-pecl-imagick php7-zip php7-bcmath php7-gmp php7-ftp php7-pecl-ssh2 libwebp-dev libzip-dev \
    libjpeg-turbo-dev supervisor curl git openssh-client mysql-client imagemagick-dev libtool imagemagick \
    ghostscript

RUN rm -rf /etc/localtime \
    && ln -s /usr/share/zoneinfo/"Europe/Berlin" /etc/localtime \
    && echo "Europe/Berlin" > /etc/timezone

RUN rm -rf /var/cache/apk/*

RUN set -ex \
  && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
  && php composer-setup.php --2.2 --install-dir=/usr/local/bin --filename=composer \
  && php -r "unlink('composer-setup.php');" \
  && chmod +x /usr/local/bin/composer

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY config/php.ini /etc/php7/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy Entrypoint
COPY start.sh /
RUN chmod +x /start.sh

RUN chown -R www-data:www-data /var/www

WORKDIR /var/www

# Expose the port nginx is reachable on
EXPOSE 8080

ENTRYPOINT ["/start.sh"]