FROM alpine:3.18

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

RUN apk --no-cache --update add tzdata php82 php82-fpm php82-pdo_mysql php82-json php82-iconv php82-openssl \
    php82-curl php82-ctype php82-zlib php82-xml php82-phar php82-intl php82-session php82-simplexml php82-soap \
    php82-fileinfo php82-dom php82-tokenizer php82-pdo php82-xmlreader php82-xmlwriter php82-mbstring php82-gd \
    php82-pecl-imagick php82-pecl-mongodb php82-zip php82-bcmath php82-gmp php82-ftp php82-pecl-ssh2 php82-sodium libwebp-dev libzip-dev \
    libjpeg-turbo-dev supervisor curl git openssh-client mysql-client imagemagick-dev libtool imagemagick \
    ghostscript && ln -s /usr/bin/php82 /usr/bin/php

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
COPY config/fpm-pool.conf /etc/php82/php-fpm.d/www.conf
COPY config/php.ini /etc/php82/conf.d/zzz_custom.ini

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