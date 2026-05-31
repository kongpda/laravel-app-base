# laravel-app-base

Shared Docker **base images** for khable's Laravel projects — both **Livewire**
and **Inertia (React SSR)** stacks.

Built on [`serversideup/php`](https://serversideup.net/open-source/docker-php/) — we
do **not** reinvent the PHP runtime. serversideup already gives us PID-1 signal
handling, a non-root user, a healthcheck, opcache, and env-driven PHP config.
This repo only adds the extensions this stack needs (and Node, for Inertia SSR).

Build once, reuse across every project. Per-project images stay thin: `FROM`
this base, copy code + built assets, done.

## Images

Published to GHCR by `.github/workflows/build.yml`:

| Image | Base | Use for | node? |
|-------|------|---------|-------|
| `ghcr.io/kongpda/laravel-app-base` | `serversideup/php:8.4-fpm-nginx` | **Livewire** (all roles) **+ Inertia** web / queue / scheduler | ❌ |
| `ghcr.io/kongpda/laravel-app-ssr` | `serversideup/php:8.4-cli` + Node | **Inertia ssr** role only | ✅ |

Why two and not three: Livewire and non-SSR Inertia have identical runtime needs
(PHP + fpm-nginx, no node), so they share `laravel-app-base`. Only the Inertia
SSR role runs Node at runtime (`php artisan inertia:start-ssr` boots a Node
process for the `bootstrap/ssr/ssr.js` bundle).

Both images add PHP extensions: `pdo_pgsql`, `redis`, `bcmath`.
Web root is `/var/www/html/public`. nginx listens on `8080` (non-root).
Tags: `latest` (main branch), `vX.Y.Z` (git tag), short commit SHA.

## Use in a project

Copy `examples/app.Dockerfile` into your Laravel repo root. Outline:

```dockerfile
FROM oven/bun:1 AS assets        # build frontend assets
FROM composer:2 AS vendor        # install PHP deps (no dev)
FROM ghcr.io/kongpda/laravel-app-base:latest AS app
COPY --from=vendor /app/vendor /var/www/html/vendor
COPY --from=assets /app/public/build /var/www/html/public/build
```

- **Livewire project**: that's it — no SSR, no extra image.
- **Inertia + SSR**: also `COPY` `bootstrap/ssr`, and build a second image
  `FROM ghcr.io/kongpda/laravel-app-ssr` for the ssr role running
  `php artisan inertia:start-ssr`.

## Gotchas

- **Node is only in the SSR image.** Livewire and web/queue/scheduler don't need
  it at runtime. Asset *building* happens in a separate Bun stage (see example).
- **Inertia Wayfinder needs PHP at build time.** `bun run build` → `prebuild` →
  `wayfinder:generate` calls `php artisan`. The pure-Bun build stage has no PHP,
  so either commit the generated `@/actions` / `@/routes` files, or generate them
  in a PHP+Node stage. Otherwise `vite build` fails on missing imports.
  (Livewire projects: not applicable, no Wayfinder.)
- **Enable OPcache in production.** serversideup ships it off; set
  `PHP_OPCACHE_ENABLE=1` in your deploy env (no image change).
- **Pin in production.** `8.4-fpm-nginx` floats. Pin to a serversideup release tag
  (or digest) for reproducible builds.

## Security scanning

CI gates every push: a [Trivy](https://github.com/aquasecurity/trivy) secret scan
of the source, then each image is built and scanned for **fixable** HIGH/CRITICAL
CVEs **before** it is pushed to GHCR. A finding fails the job and nothing is
published. Upstream OS CVEs with no fix yet are ignored (`--ignore-unfixed`) so
releases aren't blocked on things we can't patch.

Run the same checks locally before pushing:

```bash
./scan.sh        # requires: brew install trivy
```

## Build locally

```bash
docker build -t laravel-app-base:test -f Dockerfile .
docker build -t laravel-app-ssr:test  -f Dockerfile.ssr .
```

Bump PHP/Node via build args: `--build-arg PHP_VERSION=8.4 --build-arg NODE_VERSION=22`.
