# syntax=docker/dockerfile:1
#
# Laravel + Inertia base RUNTIME image — web / queue / scheduler roles.
#
# Thin layer on top of serversideup/php (production-hardened: PID-1 signal
# handling, non-root user, healthcheck, opcache, env-driven PHP config).
# We only add the PHP extensions this stack needs. Nothing else reinvented.
#
# Web root is /var/www/html/public. nginx listens on 8080 (non-root).
ARG PHP_VERSION=8.4
ARG VARIANT=fpm-nginx
FROM serversideup/php:${PHP_VERSION}-${VARIANT}

LABEL org.opencontainers.image.source="https://github.com/kongpda/laravel-inertia-base"
LABEL org.opencontainers.image.description="Laravel + Inertia base runtime (serversideup/php + pdo_pgsql, redis, bcmath)"

USER root
# pdo_pgsql + redis + bcmath required by this stack (see project composer.json ext-*)
RUN install-php-extensions pdo_pgsql redis bcmath
USER www-data
