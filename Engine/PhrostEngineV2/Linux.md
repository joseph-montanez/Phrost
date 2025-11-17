# Installing on Linux

    sudo apt-get install php8.3-dev libphp8.3-embed

    clear && \
        cp -Ra assets .build/x86_64-unknown-linux-gnu/debug/ && \
        PHP_SRC_ROOT=build/php-src swift run \
            -Xcc -D_GNU_SOURCE -Xcc -U__SSE2__ -Xcc -fno-builtin \
            -Xcc -Ibuild/php-src \
            -Xcc -Ibuild/php-src/main \
            -Xcc -Ibuild/php-src/Zend \
            -Xcc -Ibuild/php-src/TSRM \
            -Xlinker -lphp8.3

    clear && \
    PHP_SRC_ROOT=build/php-src swift build \
        -Xcc -D_GNU_SOURCE \
        -Xcc -U__SSE2__ \
        -Xcc -fno-builtin \
        -Xcc -Ibuild/php-src \
        -Xcc -Ibuild/php-src/main \
        -Xcc -Ibuild/php-src/Zend \
        -Xcc -Ibuild/php-src/TSRM \
        -Xlinker -Lbuild/php-src/libs \
        -Xlinker build/php-src/libs/libphp.a \
        -Xcc -DZTS \
        -Xswiftc -DZTS && \
    ln -sf $(pwd)/assets .build/debug/assets && \
    ./.build/debug/SwiftPHPClient