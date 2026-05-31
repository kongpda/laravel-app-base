# laravel-inertia-base

Shared Docker **base images** for khable's Laravel + Inertia (React SSR) projects.

Built on [`serversideup/php`](https://serversideup.net/open-source/docker-php/) — we
do **not** reinvent the PHP runtime. serversideup already gives us PID-1 signal
handling, a non-root user, a healthcheck, opcache, and env-driven PHP config.
This repo only adds the extensions this stack needs (and Node, for SSR).

Build once, reuse across every project. Per-project images stay thin: `FROM`
this base, copy code + built assets, done.

## Images

Published to GHCR by `.github/workflows/build.yml`:

| Image | Base | Use for | Notes |
|-------|------|---------|-------|
| `ghcr.io/kongpda/laravel-inertia-base` | `serversideup/php:8.4-fpm-nginx` | **web / queue / scheduler** | nginx+fpm, web root `/var/www/html/public`, listens on `8080` |
| `ghcr.io/kongpda/laravel-inertia-ssr` | `serversideup/php:8.4-cli` + Node | **ssr** role | runs `php artisan inertia:start-ssr` (PHP boots a Node process) |

Both add PHP extensions: `pdo_pgsql`, `redis`, `bcmath`.

Tags: `latest` (main branch), `vX.Y.Z` (git tag), short commit SHA.

## Use in a project

Copy `examples/app.Dockerfile` into your Laravel + Inertia repo root. Outline:

```dockerfile
FROM oven/bun:1 AS assets        # build client + SSR bundle
FROM composer:2 AS vendor        # install PHP deps (no dev)
FROM ghcr.io/kongpda/laravel-inertia-base:latest AS app
COPY --from=vendor /app/vendor /var/www/html/vendor
COPY --from=assets /app/public/build /var/www/html/public/build
COPY --from=assets /app/bootstrap/ssr /var/www/html/bootstrap/ssr
```

For the SSR Kamal role, build the same code `FROM ghcr.io/kongpda/laravel-inertia-ssr`
and run `php artisan inertia:start-ssr`.

## Gotchas

- **Node is only in the SSR image.** web/queue/scheduler don't need it at runtime.
  Asset *building* happens in a separate Bun stage (see example), not in these images.
- **Wayfinder needs PHP at build time.** `bun run build` → `prebuild` → `wayfinder:generate`
  calls `php artisan`. The pure-Bun build stage has no PHP, so either commit the
  generated `@/actions` / `@/routes` files, or generate them in a PHP+Node stage.
  Otherwise `vite build` fails on missing imports.
- **Pin in production.** `8.4-fpm-nginx` floats. Pin to a serversideup release tag
  (or digest) for reproducible builds.

## Build locally

```bash
docker build -t laravel-inertia-base:test -f Dockerfile .
docker build -t laravel-inertia-ssr:test  -f Dockerfile.ssr .
```

Bump PHP/Node via build args: `--build-arg PHP_VERSION=8.4 --build-arg NODE_VERSION=22`.
