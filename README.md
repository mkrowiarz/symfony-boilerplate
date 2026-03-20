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
mkdir my-project && cd my-project
../symfony-boilerplate/bootstrap.sh
```

## What It Does

The script walks you through an interactive setup using [gum](https://github.com/charmbracelet/gum):

1. **Project name** — defaults to current directory
2. **Symfony version** — 8.0.*, 7.2.*, or 7.1.*
3. **Stability** — stable, dev, RC, or beta
4. **Extra packages** — select from Symfony packs and bundles
5. **GitHub Actions** — optional CI and release workflows
6. **FluentCI** — optional local CI pipeline powered by Dagger
7. **Docker build cache** — option to skip cache for clean builds
8. **Git init** — optional repository initialization

Then it:

1. Downloads the [dunglas/symfony-docker](https://github.com/dunglas/symfony-docker) skeleton
2. Pins your chosen Symfony version and stability
3. Builds Docker images
4. Starts the containers to scaffold the Symfony project (first boot)
5. Installs selected extra packages via `composer require` (Flex recipes run automatically)
6. Rebuilds images to compile any new PHP extensions added by recipes (e.g., `pdo_pgsql`)
7. Restarts with all services (e.g., database container from orm-pack)
8. Stops the stack — ready for you to start when needed

## Available Packages

| Package | Description |
|---|---|
| `symfony/webapp-pack` | Full webapp: Twig, ORM, Security, Mailer, and more |
| `symfony/orm-pack` | Doctrine ORM with migrations |
| `symfony/twig-pack` | Twig templating |
| `symfony/security-bundle` | Authentication and authorization |
| `symfony/mailer` | Email sending |
| `symfony/messenger` | Message queues and async processing |
| `symfony/serializer-pack` | Serializer with encoders and normalizers |
| `symfony/mercure-bundle` | Real-time updates with Mercure |
| `symfony/test-pack` | Functional and end-to-end testing |
| `symfony/debug-pack` | Debug toolbar and profiler |
| `symfony/maker-bundle` | Code generation for controllers, entities, etc. |

Packages are installed via `composer require`, which triggers Symfony Flex recipes. Recipes may modify your `Dockerfile`, `compose.yaml`, and configuration files automatically.

## Requirements

- [Docker Compose](https://docs.docker.com/compose/install/) v2.10+
- [gum](https://github.com/charmbracelet/gum) (the script will offer to install it via `go install` if missing)
- curl, git

## GitHub Actions

When enabled, the script downloads two workflows:

- **ci.yaml** — builds dev/prod images, lints, and runs tests on push/PR
- **release.yaml** — builds and pushes a production image to GHCR on `v*` tags

## FluentCI

When enabled, the bootstrap downloads a wrapper script (`fluentci.sh`) that runs CI checks locally using the published [symfony_pipeline](https://fluentci.io/pipeline/symfony_pipeline) from the FluentCI registry — no CI provider needed.

### Prerequisites

```bash
brew install fluentci-io/tap/fluentci
```

Requires [Docker](https://docs.docker.com/get-docker/).

### Usage

| Command | What it does |
|---|---|
| `./fluentci.sh` | Runs CI checks (container lint, YAML lint, PHPUnit) |
| `./fluentci.sh lint` | Linters only |
| `./fluentci.sh test` | PHPUnit only |
| `./fluentci.sh phpcs` | PHP CodeSniffer (PSR-12) |
| `./fluentci.sh phpstan` | PHPStan static analysis |
| `./fluentci.sh all` | Every available check |

You can also run pipeline jobs directly:

```bash
fluentci run symfony_pipeline containerLint yamlLint phpUnit
```

## After Bootstrap

Start the stack:

```bash
docker compose up --wait
```

Open `https://localhost` and accept the self-signed TLS certificate.

Stop the stack:

```bash
docker compose down --remove-orphans
```

## Troubleshooting

### TLS errors with OrbStack / reverse proxies

If you see `502 Bad Gateway` or TLS errors like `tls: internal error`, it's likely a conflict between Caddy's automatic HTTPS and your local proxy (e.g., OrbStack).

To disable Caddy's automatic HTTPS and serve over plain HTTP, set `SERVER_NAME` in your `.env`:

```bash
SERVER_NAME=":80"
```

Then rebuild and restart:

```bash
docker compose up --build --wait
```

The app will be available at `http://localhost` (no TLS).

You can also pass `SERVER_NAME` inline without editing `.env`:

```bash
SERVER_NAME=myapp.localhost docker compose up --build --wait
```

For more details, see the [dunglas/symfony-docker TLS docs](https://github.com/dunglas/symfony-docker/blob/main/docs/tls.md).

### Database connection errors

If the PHP container reports `could not find driver` when connecting to PostgreSQL, the Docker image needs to be rebuilt so the `pdo_pgsql` extension (added by the Doctrine Flex recipe) is compiled:

```bash
docker compose down
docker compose build
docker compose up --wait
```

## Credits

Built on top of [dunglas/symfony-docker](https://github.com/dunglas/symfony-docker) by [Kévin Dunglas](https://github.com/dunglas).
