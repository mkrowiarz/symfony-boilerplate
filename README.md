# Symfony Boilerplate

Interactive bootstrap script for scaffolding a new Symfony project using [dunglas/symfony-docker](https://github.com/dunglas/symfony-docker) — a Docker-based installer and runtime for Symfony powered by FrankenPHP.

## Quick Start

```bash
mkdir my-project && cd my-project
curl -sL https://raw.githubusercontent.com/mkrowiarz/symfony-boilerplate/main/bootstrap.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/mkrowiarz/symfony-boilerplate.git
cd my-project
../symfony-boilerplate/bootstrap.sh
```

## What It Does

The script walks you through an interactive setup using [gum](https://github.com/charmbracelet/gum):

1. **Project name** — defaults to current directory
2. **Symfony version** — 8.0.*, 7.2.*, or 7.1.*
3. **Stability** — stable, dev, RC, or beta
4. **Extra packages** — Doctrine ORM, Mercure, Mailer, Messenger, PHPUnit
5. **GitHub Actions** — optional CI and release workflows
6. **Git init** — optional repository initialization

Then it downloads the [dunglas/symfony-docker](https://github.com/dunglas/symfony-docker) skeleton, pins your chosen Symfony version, builds Docker images, and starts the application.

## Requirements

- [Docker Compose](https://docs.docker.com/compose/install/) v2.10+
- [gum](https://github.com/charmbracelet/gum) (the script will offer to install it via `go install` if missing)
- curl, git

## GitHub Actions

When enabled, the script downloads two workflows:

- **ci.yaml** — builds dev/prod images, lints, and runs tests on push/PR
- **release.yaml** — builds and pushes a production image to GHCR on `v*` tags

## Credits

Built on top of [dunglas/symfony-docker](https://github.com/dunglas/symfony-docker) by [Kévin Dunglas](https://github.com/dunglas).
