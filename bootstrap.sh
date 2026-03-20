#!/usr/bin/env bash
set -euo pipefail

# Wrap everything in main() so bash reads the entire script before executing.
# Without this, `curl | bash` fails because `exec < /dev/tty` cuts off
# bash's ability to read the rest of the script from stdin.
main() {
  TEMPLATE_REPO="dunglas/symfony-docker"
  BOILERPLATE_REPO="mkrowiarz/symfony-boilerplate"
  BOILERPLATE_BRANCH="main"

  # When piped via curl | bash, stdin is not a TTY.
  # Redirect interactive input from /dev/tty so gum and read work.
  if [ ! -t 0 ]; then
    exec < /dev/tty
  fi

  # --- Check dependencies ---
  for cmd in docker curl git; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: $cmd is required but not installed." >&2
      exit 1
    fi
  done

  if ! command -v gum &>/dev/null; then
    echo "gum is required but not installed."
    echo ""
    read -rp "Install gum via 'go install github.com/charmbracelet/gum@latest'? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      if ! command -v go &>/dev/null; then
        echo "Error: go is required to install gum but not found." >&2
        echo "Install gum manually: https://github.com/charmbracelet/gum#installation" >&2
        exit 1
      fi
      go install github.com/charmbracelet/gum@latest
      echo "gum installed successfully."
    else
      echo "Aborting. Install gum manually: https://github.com/charmbracelet/gum#installation" >&2
      exit 1
    fi
  fi

  # --- Header ---
  gum style \
    --border double \
    --border-foreground 212 \
    --padding "1 2" \
    --margin "1 0" \
    "Symfony 8 Project Bootstrap" \
    "Using dunglas/symfony-docker"

  # --- Project name ---
  PROJECT_NAME=$(gum input \
    --placeholder "my-symfony-app" \
    --prompt "Project name: " \
    --value "$(basename "$PWD")")

  # --- Symfony version ---
  SYMFONY_VERSION=$(gum choose \
    --header "Symfony version:" \
    "8.0.*" "7.2.*" "7.1.*")

  # --- Stability ---
  if [ "$SYMFONY_VERSION" = "8.0.*" ]; then
    DEFAULT_STABILITY="dev"
  else
    DEFAULT_STABILITY="stable"
  fi
  STABILITY=$(gum choose \
    --header "Stability:" \
    --selected "$DEFAULT_STABILITY" \
    "stable" "dev" "RC" "beta")

  # --- Extra packages ---
  EXTRAS=$(gum choose \
    --no-limit \
    --header "Install extra packages? (space to select)" \
    "symfony/webapp-pack — Full webapp: Twig, ORM, Security, Mailer, and more" \
    "symfony/orm-pack — Doctrine ORM" \
    "symfony/twig-pack — Twig templating" \
    "symfony/security-bundle — Authentication and authorization" \
    "symfony/mailer — Email sending" \
    "symfony/messenger — Message queues and async processing" \
    "symfony/serializer-pack — Serializer with encoders and normalizers" \
    "symfony/mercure-bundle — Real-time updates with Mercure" \
    "symfony/test-pack — Functional and end-to-end testing" \
    "symfony/debug-pack — Debug toolbar and profiler" \
    "symfony/maker-bundle — Code generation for controllers, entities, etc.")

  # --- CI/CD ---
  INCLUDE_CI=$(gum confirm "Include GitHub Actions workflows (CI + Release)?" && echo "yes" || echo "no")
  INCLUDE_FLUENTCI=$(gum confirm "Include FluentCI pipeline (run CI locally with Dagger)?" && echo "yes" || echo "no")

  # --- Docker build cache ---
  NO_CACHE=$(gum confirm --default=yes "Build Docker images without cache?" && echo "yes" || echo "no")

  # --- Init git ---
  INIT_GIT=$(gum confirm "Initialize git repository?" && echo "yes" || echo "no")

  # --- Summary ---
  gum style \
    --border rounded \
    --border-foreground 39 \
    --padding "1 2" \
    --margin "1 0" \
    "Project:    $PROJECT_NAME" \
    "Symfony:    $SYMFONY_VERSION" \
    "Stability:  $STABILITY" \
    "Extras:     ${EXTRAS:-none}" \
    "GitHub CI:  $INCLUDE_CI" \
    "FluentCI:   $INCLUDE_FLUENTCI" \
    "No cache:   $NO_CACHE" \
    "Init git:   $INIT_GIT"

  gum confirm "Proceed with setup?" || exit 0

  # --- Download skeleton ---
  gum log --level info "Downloading symfony-docker skeleton..."
  curl -sL "https://github.com/$TEMPLATE_REPO/archive/refs/heads/main.tar.gz" | tar xz --strip-components=1

  # Clean upstream docs/CI
  rm -rf docs/ .github/

  # --- Download GitHub Actions workflows from boilerplate repo ---
  if [ "$INCLUDE_CI" = "yes" ]; then
    mkdir -p .github/workflows
    for workflow in ci.yaml release.yaml; do
      curl -sL "https://raw.githubusercontent.com/$BOILERPLATE_REPO/$BOILERPLATE_BRANCH/.github/workflows/$workflow" \
        -o ".github/workflows/$workflow"
    done
    gum log --level info "Downloaded GitHub Actions workflows"
  fi

  # --- Set up FluentCI ---
  if [ "$INCLUDE_FLUENTCI" = "yes" ]; then
    curl -sL "https://raw.githubusercontent.com/$BOILERPLATE_REPO/$BOILERPLATE_BRANCH/fluentci.sh" \
      -o "fluentci.sh"
    chmod +x fluentci.sh
    gum log --level info "Downloaded FluentCI runner (./fluentci.sh)"
  fi

  # --- Pin Symfony version ---
  echo "SYMFONY_VERSION=$SYMFONY_VERSION" >> .env
  echo "STABILITY=$STABILITY" >> .env
  gum log --level info "Pinned Symfony $SYMFONY_VERSION ($STABILITY)"

  # --- Build ---
  BUILD_FLAGS="--pull"
  if [ "$NO_CACHE" = "yes" ]; then
    BUILD_FLAGS="$BUILD_FLAGS --no-cache"
  fi
  gum log --level info "Building Docker images (this may take a few minutes)..."
  docker compose build $BUILD_FLAGS

  # --- Scaffold Symfony project ---
  # The entrypoint auto-installs the Symfony skeleton on first boot
  # when composer.json is empty. We need this before installing extras.
  gum log --level info "Scaffolding Symfony project (first boot)..."
  docker compose up --wait

  # --- Install extras ---
  if [ -n "$EXTRAS" ]; then
    PACKAGES=""
    while IFS= read -r line; do
      PACKAGES="$PACKAGES $(echo "$line" | cut -d' ' -f1)"
    done <<< "$EXTRAS"
    gum log --level info "Installing:$PACKAGES"
    docker compose exec -T php composer require $PACKAGES

    # Extras may modify the Dockerfile (e.g. adding PHP extensions like pdo_pgsql)
    # and compose.yaml (e.g. adding a database service). Rebuild and restart.
    gum log --level info "Rebuilding images with new extensions..."
    docker compose down
    docker compose build
    docker compose up --wait

    # --- Post-install warnings ---
    if echo "$EXTRAS" | grep -q "symfony/orm-pack"; then
      gum style \
        --border rounded \
        --border-foreground 214 \
        --padding "1 2" \
        --margin "1 0" \
        "Note: symfony/orm-pack added a PostgreSQL service to compose.yaml." \
        "" \
        "Review and adjust:" \
        "  - POSTGRES_VERSION, POSTGRES_DB, POSTGRES_USER in .env" \
        "  - POSTGRES_PASSWORD (change the default!)" \
        "  - DATABASE_URL in .env or Symfony vault for production" \
        "  - Consider a bind-mounted volume for database data"
    fi
  fi

  # --- Stop containers ---
  gum log --level info "Stopping containers..."
  docker compose down

  # --- Init git ---
  if [ "$INIT_GIT" = "yes" ]; then
    git init
    git add -A
    git commit -m "Initial Symfony $SYMFONY_VERSION project from dunglas/symfony-docker"
    gum log --level info "Git repository initialized"
  fi

  # --- Done ---
  gum style \
    --border double \
    --border-foreground 76 \
    --padding "1 2" \
    --margin "1 0" \
    "Done! Your Symfony $SYMFONY_VERSION project is ready." \
    "" \
    "Start: docker compose up --wait" \
    "Open:  https://localhost" \
    "Stop:  docker compose down --remove-orphans"

  exit 0
}

main "$@"
