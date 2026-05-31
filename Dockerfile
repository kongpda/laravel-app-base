# syntax=docker/dockerfile:1
#
# Laravel app base RUNTIME image — Livewire + Inertia web / queue / scheduler roles.
#
# Livewire and non-SSR Inertia have identical runtime needs (PHP + fpm-nginx,
# no node), so they share this one base. Only the Inertia SSR role needs node
# (see Dockerfile.ssr).
#
# Thin layer on top of serversideup/php (production-hardened: PID-1 signal
# handling, non-root user, healthcheck, opcache, env-driven PHP config).
# We only add the PHP extensions this stack needs. Nothing else reinvented.
#
# Web root is /var/www/html/public. nginx listens on 8080 (non-root).
ARG PHP_VERSION=8.4
ARG VARIANT=fpm-nginx
FROM serversideup/php:${PHP_VERSION}-${VARIANT}

LABEL org.opencontainers.image.source="https://github.com/kongpda/laravel-app-base"
LABEL org.opencontainers.image.description="Laravel app base runtime for Livewire + Inertia (serversideup/php + pdo_pgsql, redis, bcmath)"

USER root
# pdo_pgsql + redis + bcmath required by this stack (see project composer.json ext-*).
# intl powers Laravel's Number helper (currency/number formatting) + db:show.
RUN install-php-extensions pdo_pgsql redis bcmath intl
# Layer Debian security updates, install postgresql-client (pg_dump — needed for
# spatie/laravel-backup DB dumps), and drop the kernel-header dev packages
# (build-only leftovers, unused at runtime — only add un-actionable scanner noise).
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends postgresql-client \
 && apt-get purge -y linux-libc-dev \
 && rm -rf /var/lib/apt/lists/*
USER www-data
