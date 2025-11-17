FROM swift:6.2-jammy

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg2 lsb-release software-properties-common \
      build-essential pkg-config autoconf automake libtool cmake git unzip zip \
      libssl-dev libcurl4-openssl-dev libxml2-dev zlib1g-dev && \
    add-apt-repository ppa:ondrej/php -y && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      php8.4 php8.4-cli php8.4-dev php8.4-xml php8.4-mbstring php8.4-zip php8.4-curl php-pear && \
    update-alternatives --set php /usr/bin/php8.4 && \
    php -v && phpize -v && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /work