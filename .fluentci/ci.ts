import { dag } from "jsr:@fluentci/sdk@0.4.3";

/**
 * Create a Pkgx environment with PHP and Composer installed.
 */
function phpEnv() {
  return dag
    .pipeline("symfony")
    .pkgx()
    .withPackages(["php", "composer", "git", "zip", "unzip"])
    .withCache("/app/vendor", dag.cache("composer-vendor"))
    .withEnvVariable("COMPOSER_ALLOW_SUPERUSER", "1")
    .withWorkdir("/app")
    .withExec(["composer", "install", "--no-interaction", "--no-progress"]);
}

/**
 * Lint the Symfony dependency injection container.
 */
async function lintContainer(): Promise<string> {
  return await phpEnv()
    .withExec(["php", "bin/console", "lint:container"])
    .stdout();
}

/**
 * Lint YAML configuration files.
 */
async function lintYaml(): Promise<string> {
  return await phpEnv()
    .withExec(["php", "bin/console", "lint:yaml", "config", "--parse-tags"])
    .stdout();
}

/**
 * Run PHPUnit tests.
 */
async function phpUnit(): Promise<string> {
  return await phpEnv()
    .withExec(["php", "bin/phpunit"])
    .stdout();
}

/**
 * Build the production Docker image.
 */
async function buildProd(): Promise<string> {
  return await dag
    .pipeline("build")
    .pkgx()
    .withPackages(["docker"])
    .withWorkdir("/app")
    .withExec([
      "docker",
      "build",
      "--target",
      "frankenphp_prod",
      "-t",
      "app-php-prod:latest",
      ".",
    ])
    .stdout();
}

/**
 * Build and push the production image to a container registry.
 * Set REGISTRY and IMAGE_NAME env vars before running.
 *
 * Requires: docker login to your registry beforehand.
 */
async function deploy(): Promise<string> {
  const registry = Deno.env.get("REGISTRY") || "ghcr.io";
  const imageName = Deno.env.get("IMAGE_NAME");
  const tag = Deno.env.get("IMAGE_TAG") || "latest";

  if (!imageName) {
    throw new Error(
      "IMAGE_NAME env var is required (e.g. IMAGE_NAME=myorg/myapp)"
    );
  }

  const fullTag = `${registry}/${imageName}:${tag}`;

  return await dag
    .pipeline("deploy")
    .pkgx()
    .withPackages(["docker"])
    .withWorkdir("/app")
    .withExec([
      "docker",
      "build",
      "--target",
      "frankenphp_prod",
      "-t",
      fullTag,
      ".",
    ])
    .withExec(["docker", "push", fullTag])
    .stdout();
}

// --- Determine which jobs to run ---
const job = Deno.args[0];

switch (job) {
  case "build":
    console.log(await buildProd());
    break;
  case "deploy":
    console.log(await deploy());
    break;
  default:
    // Default: run all CI checks
    console.log("--- Lint container ---");
    console.log(await lintContainer());

    console.log("--- Lint YAML ---");
    console.log(await lintYaml());

    console.log("--- PHPUnit ---");
    console.log(await phpUnit());
    break;
}
