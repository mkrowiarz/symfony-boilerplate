#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a Symfony 8 project using dunglas/symfony-docker
# Usage: ./bootstrap.sh [project-name]
#   project-name defaults to the current directory name

PROJECT_NAME="${1:-$(basename "$PWD")}"
TEMPLATE_REPO="dunglas/symfony-docker"

echo "==> Bootstrapping Symfony 8 project: $PROJECT_NAME"
echo "    Using template: https://github.com/$TEMPLATE_REPO"
echo ""

# 1. Download the symfony-docker skeleton (without .git history)
echo "==> Downloading symfony-docker skeleton..."
curl -sL "https://github.com/$TEMPLATE_REPO/archive/refs/heads/main.tar.gz" \
  | tar xz --strip-components=1

# 2. Remove upstream docs and CI
rm -rf docs/ .github/

# 3. Copy our GitHub Actions workflows
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/.github" ]; then
  cp -r "$SCRIPT_DIR/.github" .github
  echo "==> Copied GitHub Actions workflows"
fi

# 4. Pin to Symfony 8 (dev until stable release)
echo "SYMFONY_VERSION=8.0.*" >> .env
echo "STABILITY=dev" >> .env

# 5. Initialize git repo
git init
git add -A
git commit -m "Initial Symfony 8 project from dunglas/symfony-docker"

# 6. Build and start
echo ""
echo "==> Building Docker images (this may take a few minutes)..."
docker compose build --pull --no-cache

echo ""
echo "==> Starting containers..."
docker compose up --wait

echo ""
echo "==> Done! Open https://localhost and accept the self-signed TLS certificate."
echo "    Stop with: docker compose down --remove-orphans"
