#!/usr/bin/env bash
# Scripts/ubuntu_ext.sh
set -euo pipefail

: "${CONFIG:=debug}"
: "${PHP_BIN:=php}"
: "${PHP_CONFIG_BIN:=php-config}"

PHP_INCLUDES="$(${PHP_CONFIG_BIN} --includes)"
PHP_API_DIR="$(echo "${PHP_INCLUDES}" | tr ' ' '\n' | grep -- '-I/' | head -n1 | sed 's/^-I//')"
ZTS_DETECT="$(${PHP_BIN} -i | awk -F'=> ' '/^Thread Safety/ {print tolower($2)}')"
DEBUG_DETECT="$(${PHP_BIN} -i | awk -F'=> ' '/^Debug Build/ {print tolower($2)}')"

export ZTS="${ZTS:-$([[ "${ZTS_DETECT}" == "enabled" ]] && echo 1 || echo 0)}"
export ZEND_DEBUG="${ZEND_DEBUG:-$([[ "${DEBUG_DETECT}" == "yes" ]] && echo 1 || echo 0)}"
export PHP_INCLUDE_BASE="${PHP_INCLUDE_BASE:-${PHP_API_DIR}}"

mkdir -p build
ln -sfn "${PHP_API_DIR}" build/php-src

SWIFT_CMD=(swift build --configuration "${CONFIG}" -Xcc -D_GNU_SOURCE -Xcc -fno-builtin)
while read -r inc; do [[ -n "$inc" ]] && SWIFT_CMD+=(-Xcc "$inc"); done < <(echo "${PHP_INCLUDES}")
[[ "${ZTS}" == "1" ]] && SWIFT_CMD+=(-Xcc -DZTS=1)
[[ "${ZEND_DEBUG}" == "1" ]] && SWIFT_CMD+=(-Xcc -DZEND_DEBUG=1)
[[ "${CONFIG}" == "release" ]] && SWIFT_CMD+=(-Xswiftc -O -Xswiftc -enable-bare-slash-regex)

printf 'ZTS=%s ZEND_DEBUG=%s\n' "${ZTS}" "${ZEND_DEBUG}"
printf 'Executing:\n%s\n' "$(printf '%q ' "${SWIFT_CMD[@]}")"
"${SWIFT_CMD[@]}"

BIN_DIR="$(swift build --show-bin-path --configuration "${CONFIG}")"
SO_PATH="${BIN_DIR}/libSwiftPHPExtension.so"
[[ -f "${SO_PATH}" ]] || SO_PATH="${BIN_DIR}/SwiftPHPExtension/libSwiftPHPExtension.so"
echo "Built: ${SO_PATH}"

nm -D --defined-only "${SO_PATH}" | grep -E ' get_module$' || true
"${PHP_BIN}" -dextension="${SO_PATH}" -v || true