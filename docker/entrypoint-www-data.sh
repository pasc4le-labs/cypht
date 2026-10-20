#!/usr/bin/env sh
#
# Entrypoint wrapper for the GHCR image (docker/Dockerfile.ghcr).
#
# Problem it fixes, reproduced against cypht/cypht:2.13.0 with
# DB_DRIVER=sqlite: `scripts/setup_database.php` runs as root and creates the
# database file owned by root:root 0644, while nginx/php-fpm run as www-data
# (uid 33). Reads work, so the app looks healthy, but every write from the web
# app fails with "SQLSTATE[HY000]: General error: 8 attempt to write a readonly
# database" - the session/settings writes that login depends on.
#
# The stock entrypoint chowns the users/attachments directories but never the
# database file, and it does so *after* the database is created, so the fix has
# to happen before it runs: pre-create the file, give it to www-data, and hand
# the whole data root over.
#
# Everything else is upstream behaviour: this wrapper ends by exec'ing the
# image's own docker-entrypoint.sh, which runs the setup scripts, generates the
# site config and starts supervisord.
set -e

DATA_ROOT=/var/lib/hm3
USER_SETTINGS_DIR="${USER_SETTINGS_DIR:-${DATA_ROOT}/users}"
ATTACHMENT_DIR="${ATTACHMENT_DIR:-${DATA_ROOT}/attachments}"

if [ "$(id -u)" = "0" ]; then
    mkdir -p "${USER_SETTINGS_DIR}" "${ATTACHMENT_DIR}"

    # SQLite: DB_NAME is the database file itself (lib/db.php build_dsn()).
    if [ "${DB_DRIVER}" = "sqlite" ] && [ -n "${DB_NAME}" ]; then
        mkdir -p "$(dirname "${DB_NAME}")"
        touch "${DB_NAME}"
        chmod 0664 "${DB_NAME}"
        chown www-data:www-data "${DB_NAME}"
    fi

    chown -R www-data:www-data "${DATA_ROOT}"
fi

exec docker-entrypoint.sh "$@"
