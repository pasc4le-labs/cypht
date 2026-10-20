# GHCR image (`ghcr.io/pasc4le-labs/cypht`)

This fork publishes its own image because upstream's image cannot run a
**SQLite** install: `scripts/setup_database.php` runs as root, so the database
file is created owned by root while nginx/php-fpm run as `www-data` (uid 33).
The web app then fails on every write with

```
SQLSTATE[HY000]: General error: 8 attempt to write a readonly database
```

`docker/entrypoint-www-data.sh` fixes that (pre-create the file, hand `/var/lib/hm3`
to `www-data`) and then execs the image's own `docker-entrypoint.sh`;
`docker/Dockerfile.ghcr` builds on top of upstream's multi-arch image with only
that entrypoint replaced.

## Publishing

`.github/workflows/ghcr-image.yml` runs on a `v*` tag (or by hand, on the
`master` ref) and pushes `linux/amd64` + `linux/arm64`, then pulls the pushed
image and smoke-tests it: HTTP 200, database owned by uid 33, php-fpm can write
it, a real login succeeds, a bad password is rejected.

The tag carries the upstream version, so bumping the base is just a new tag:

```bash
git tag v2.13.0-r1 && git push origin v2.13.0-r1   # FROM cypht/cypht:2.13.0
git tag v2.14.0-r1 && git push origin v2.14.0-r1   # FROM cypht/cypht:2.14.0
```

Iterating on the workflow itself: use pre-release tags (`v2.13.0-a.1`,
`-a.2`, ...) — they publish too, which is what makes the run self-verifying.

## Using it

```yaml
services:
  cypht:
    image: ghcr.io/pasc4le-labs/cypht:v2.13.0-r1
    environment:
      AUTH_TYPE: DB
      DB_DRIVER: sqlite
      DB_NAME: /var/lib/hm3/db/cypht.db
    volumes:
      - ./db:/var/lib/hm3/db
```

The upstream demo compose uses MariaDB instead; SQLite keeps it to one container
(no second service, no database secret) at the cost of a single writer, which is
fine for a personal aggregation instance.
