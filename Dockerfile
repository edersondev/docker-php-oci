FROM ubuntu:18.04
LABEL maintainer="Ederson Ferreira <ederson.dev@gmail.com>"

ARG PHP_VERSION=7.3
ARG OCI8_VERSION=2.2.0

ENV TZ=America/Sao_Paulo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

COPY ondrej.pgp /root/ondrej.pgp

RUN apt-get update && apt-get install -y --no-install-recommends gnupg \
 && cat /root/ondrej.pgp | apt-key add \
 && echo "deb http://ppa.launchpad.net/ondrej/php/ubuntu bionic main" >> /etc/apt/sources.list.d/ondrej-php.list \
 && echo "deb-src http://ppa.launchpad.net/ondrej/php/ubuntu bionic main" >> /etc/apt/sources.list.d/ondrej-php.list

# install oci
COPY ./instantclient/instantclient-basic-linux.x64-12.2.0.1.0.zip \
     ./instantclient/instantclient-sdk-linux.x64-12.2.0.1.0.zip \
     ./instantclient/instantclient-sqlplus-linux.x64-12.2.0.1.0.zip /tmp/

RUN apt-get update && apt-get install -y \
    apache2 \
    libapache2-mod-php${PHP_VERSION} \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION} \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-json \
    php${PHP_VERSION}-pdo \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-dev \
    php${PHP_VERSION}-memcache \
    php${PHP_VERSION}-xdebug \
    unzip \
    zip \
    libaio-dev \
    curl \
    nano \
    zlib1g-dev \
    build-essential \
    libaio1 \
    locales \
    && unzip -o /tmp/instantclient-basic-linux.x64-12.2.0.1.0.zip -d /usr/local/ \
         && unzip -o /tmp/instantclient-sdk-linux.x64-12.2.0.1.0.zip -d /usr/local/ \
         && unzip -o /tmp/instantclient-sqlplus-linux.x64-12.2.0.1.0.zip -d /usr/local/ \
         && ln -s /usr/local/instantclient_12_2 /usr/local/instantclient \
         && ln -s /usr/local/instantclient/libclntsh.so.12.1 /usr/local/instantclient/libclntsh.so \
         && ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus \
         && echo 'export LD_LIBRARY_PATH="/usr/local/instantclient"' >> /root/.bashrc \
         && echo 'export ORACLE_HOME="/usr/local/instantclient"' >> /root/.bashrc \
         && echo 'umask 002' >> /root/.bashrc \
         && echo /usr/local/instantclient > /etc/ld.so.conf.d/oracle-instantclient.conf \
         && ldconfig

RUN localedef -i pt_BR -c -f UTF-8 -A /usr/share/locale/locale.alias pt_BR.UTF-8

ENV LANG pt_BR.UTF-8
ENV LC_ALL pt_BR.UTF-8

# Habilita o modo de reescrita do apache
RUN a2enmod rewrite

ENV APACHE_LOCK_DIR="/var/lock"
ENV APACHE_PID_FILE="/var/run/apache2.pid"
ENV APACHE_RUN_USER="www-data"
ENV APACHE_RUN_GROUP="www-data"
ENV APACHE_LOG_DIR="/var/log/apache2"

# Copia o arquivo de virtualhost
COPY 000-default.conf /etc/apache2/sites-available/000-default.conf

# Install composer
WORKDIR /usr/local/bin/
RUN curl -sS https://getcomposer.org/installer | php
RUN chmod +x composer.phar
RUN mv composer.phar composer

# Set path bin
WORKDIR /root
RUN echo 'export PATH="$PATH:$HOME/.composer/vendor/bin"' >> ~/.bashrc

COPY oci8-${OCI8_VERSION}.tgz /tmp/

RUN echo "instantclient,/usr/local/instantclient"|pecl install /tmp/oci8-${OCI8_VERSION}.tgz

# Create file on modules availabe
RUN echo "; configuration for php oracle module\nextension=oci8.so" > /etc/php/${PHP_VERSION}/mods-available/oci8.ini

# Enable mod
RUN phpenmod oci8

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
	echo 'opcache.memory_consumption=128'; \
	echo 'opcache.interned_strings_buffer=8'; \
	echo 'opcache.max_accelerated_files=4000'; \
	echo 'opcache.revalidate_freq=2'; \
	echo 'opcache.fast_shutdown=1'; \
	echo 'opcache.enable_cli=1'; \
} > /etc/php/${PHP_VERSION}/apache2/conf.d/opcache-recommended.ini

# Configuração Xdebug
RUN { \
    echo 'xdebug.remote_enable=1'; \
    echo 'xdebug.remote_autostart=1'; \
    echo 'xdebug.remote_port=9000'; \
    echo 'xdebug.remote_connect_back=1'; \
} > /etc/php/${PHP_VERSION}/apache2/conf.d/xdebug-conf.ini

RUN { \
    echo 'display_errors = on'; \
    echo '; Get the right number in https://maximivanov.github.io/php-error-reporting-calculator/'; \
    echo 'error_reporting = 22527'; \
    echo 'memory_limit = 4096M'; \
    echo 'post_max_size = 200M'; \
    echo 'upload_max_filesize = 200M'; \
    echo 'max_execution_time = 60'; \
    echo 'max_input_time = 120'; \
    echo 'date.timezone = "America/Sao_Paulo"'; \
} > /etc/php/${PHP_VERSION}/apache2/conf.d/extra-conf.ini

# Clean
RUN apt-get clean && apt-get autoclean && apt-get autoremove \
&& rm -rf /var/lib/apt/lists/* \
&& rm -rf /tmp/*

COPY apache2-foreground /usr/local/bin/
RUN chmod +x /usr/local/bin/apache2-foreground

WORKDIR /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]
