# syntax=docker/dockerfile:1
#
# EXAMPLE per-project Dockerfile. Copy into your Laravel + Inertia repo root
# and adjust. This is illustrative — the base-image repo does not build it.
#
# Build = multi-stage:
#   1. assets  — Bun builds client + SSR bundle
#   2. vendor  — Composer installs PHP deps (no dev)
#   3. app     — copy artifacts onto the shared base runtime
#
# NOTE (Wayfinder): package.json `prebuild` runs `php artisan wayfinder:generate`,
# which needs PHP. The pure-Bun assets stage has no PHP, so EITHER commit the
# generated @/actions and @/routes files to the repo, OR run wayfinder:generate
# in a stage that has both PHP and Node. Otherwise `vite build` fails on missing
# imports. Do not ship without resolving this — it will fail loud at build.

ARG BASE_IMAGE=ghcr.io/kongpda/laravel-app-base
ARG BASE_TAG=latest

# 1. Frontend assets (vite build && vite build --ssr)
FROM oven/bun:1 AS assets
WORKDIR /app
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build

# 2. PHP dependencies
FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --prefer-dist --no-interaction --optimize-autoloader
COPY . .
RUN composer dump-autoload --no-dev --optimize

# 3. Runtime (web / queue / scheduler). For the Inertia ssr role swap BASE_IMAGE
#    to ghcr.io/kongpda/laravel-app-ssr and run `php artisan inertia:start-ssr`.
FROM ${BASE_IMAGE}:${BASE_TAG} AS app
COPY --chown=www-data:www-data . /var/www/html
COPY --from=vendor --chown=www-data:www-data /app/vendor /var/www/html/vendor
COPY --from=assets --chown=www-data:www-data /app/public/build /var/www/html/public/build
COPY --from=assets --chown=www-data:www-data /app/bootstrap/ssr /var/www/html/bootstrap/ssr
