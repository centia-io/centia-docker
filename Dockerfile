FROM dunglas/frankenphp AS base

ENV SERVER_NAME=:80
ENV MAX_REQUESTS=:1000

# Enable PHP production settings
#RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN export DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update
RUN apt-get -y install git build-essential cmake libgdal-dev libwxgtk3.2-dev

# Install ogr2postgis for importing of geo spatial files
RUN cd ~ &&\
    git clone https://github.com/mapcentia/ogr2postgis.git --branch gui &&\
    cd ogr2postgis &&\
    mkdir build &&\
    cd build &&\
    cmake .. && make && make install

# Install PHP extensions
RUN install-php-extensions \
    gd \
    dba \
	redis \
	zip \
	pgsql \
	pdo_pgsql \
    pq \
    uv \
	opcache \
	zmq \
    parallel \
    pcntl

WORKDIR /app

RUN git clone https://github.com/mapcentia/geocloud2.git                   --branch connection

# Instal composer
RUN set -e; cd geocloud2/app \
    && EXPECTED_SIGNATURE="$(php -r "echo file_get_contents('https://composer.github.io/installer.sig');")" \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")" \
    && if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then echo 'Installer corrupt' >&2; rm composer-setup.php; exit 1; fi \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');"


###############################################################################
# Node.js + Grunt
###############################################################################
# We’ll still rely on nvm, but watch out for environment issues in multi-stage
# Docker builds. We’ll “export” environment variables inline as needed.
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash

SHELL ["/bin/bash", "-l", "-c"]
ENV NVM_DIR="~/.nvm"
RUN source $NVM_DIR/nvm.sh \
    && nvm install 14 \
    && nvm use 14 \
    && ln -s /root/.nvm/versions/node/v14.21.3/bin/node /usr/bin/node \
    && ln -s /root/.nvm/versions/node/v14.21.3/bin/npm /usr/bin/npm \
    && npm install -g grunt-cli

RUN cd geocloud2 &&\
    rm app/composer.lock &&\
    npm install \
    && grunt shell:composer shell:hacks

ADD conf/App.php           /app/geocloud2/app/conf/App.php
ADD conf/Connection.php    /app/geocloud2/app/conf/Connection.php

###############################################################################
# HTTP
###############################################################################
FROM base AS http

ADD CaddyFile /etc/frankenphp/Caddyfile

###############################################################################
# Event
###############################################################################
FROM base AS event

CMD ["/usr/local/bin/php", "-f", "/app/geocloud2/app/event/main.php"]



