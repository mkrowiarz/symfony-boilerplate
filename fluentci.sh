#!/usr/bin/env bash
set -euo pipefail

# FluentCI wrapper for Symfony projects.
# Uses the published symfony_pipeline from the FluentCI registry.
#
# Usage:
#   ./fluentci.sh              # Run all CI checks (lint + tests)
#   ./fluentci.sh lint         # Lint only (container + yaml)
#   ./fluentci.sh test         # PHPUnit only
#   ./fluentci.sh phpcs        # PHP CodeSniffer (PSR-12)
#   ./fluentci.sh phpstan      # PHPStan static analysis
#   ./fluentci.sh all          # Run every available check

PIPELINE="symfony_pipeline"

if ! command -v fluentci &>/dev/null; then
  echo "Error: fluentci is not installed." >&2
  echo "Install: brew install fluentci-io/tap/fluentci" >&2
  exit 1
fi

case "${1:-ci}" in
  ci)
    echo "Running CI checks (container lint, yaml lint, phpunit)..."
    fluentci run "$PIPELINE" container-lint yaml-lint phpunit
    ;;
  lint)
    echo "Running linters..."
    fluentci run "$PIPELINE" container-lint yaml-lint
    ;;
  test)
    echo "Running PHPUnit..."
    fluentci run "$PIPELINE" phpunit
    ;;
  phpcs)
    echo "Running PHP CodeSniffer..."
    fluentci run "$PIPELINE" phpcs
    ;;
  phpstan)
    echo "Running PHPStan..."
    fluentci run "$PIPELINE" phpstan
    ;;
  all)
    echo "Running all checks..."
    fluentci run "$PIPELINE" phpcs phpstan twig-lint xliff-lint yaml-lint container-lint doctrine-lint phpunit
    ;;
  *)
    # Pass through to fluentci directly
    fluentci run "$PIPELINE" "$@"
    ;;
esac
