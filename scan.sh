#!/usr/bin/env bash
#
# Local pre-push scan. Mirrors the CI gate in .github/workflows/build.yml:
#   1. secret scan of the source tree
#   2. build both images and scan for FIXABLE HIGH/CRITICAL CVEs
#
# Run before pushing if you want to catch issues without waiting on CI.
# Requires Trivy: brew install trivy
set -euo pipefail

command -v trivy >/dev/null || { echo "trivy not found. Install: brew install trivy" >&2; exit 1; }

cd "$(dirname "$0")"

echo "==> Secret scan (source)"
trivy fs --scanners secret --exit-code 1 .

scan_image() {
  local name="$1" dockerfile="$2"
  echo "==> Build ${name}"
  docker build --platform linux/amd64 -t "${name}:scan" -f "${dockerfile}" .
  echo "==> Vulnerability scan ${name} (fixable HIGH/CRITICAL)"
  trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "${name}:scan"
}

scan_image laravel-app-base Dockerfile
scan_image laravel-app-ssr  Dockerfile.ssr

echo "==> All scans passed"
