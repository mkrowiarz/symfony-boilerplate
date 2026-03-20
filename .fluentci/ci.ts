import { dag, type Directory } from "jsr:@fluentci/sdk@0.4.3";

const exclude = ["vendor", "node_modules", ".git", ".fluentci", "var"];

/**
 * Create a PHP container with Composer, ready to run Symfony commands.
 */
function baseContainer(src: Directory) {
  return dag
    .container()
    .from("pkgxdev/pkgx:latest")
    .withMountedCache("/root/.pkgx", dag.cacheVolume("pkgx-cache"))
    .withEnvVariable("COMPOSER_ALLOW_SUPERUSER", "1")
    .withExec(["pkgx", "install", "php", "composer", "git", "zip", "unzip"])
    .withMountedCache("/app/vendor", dag.cacheVolume("composer-vendor"))
    .withDirectory("/app", src, { exclude })
    .withWorkdir("/app")
    .withExec(["composer", "install", "--no-interaction", "--no-progress"]);
}

/**
 * Lint the Symfony dependency injection container.
 */
async function lintContainer(src: Directory): Promise<string> {
  return await baseContainer(src)
    .withExec(["php", "bin/console", "lint:container"])
    .stdout();
}

/**
 * Lint YAML configuration files.
 */
async function lintYaml(src: Directory): Promise<string> {
  return await baseContainer(src)
    .withExec(["php", "bin/console", "lint:yaml", "config", "--parse-tags"])
    .stdout();
}

/**
 * Run PHPUnit tests via Symfony's simple-phpunit bridge.
 */
async function phpUnit(src: Directory): Promise<string> {
  return await baseContainer(src)
    .withExec(["php", "bin/phpunit"])
    .stdout();
}

// --- Run all checks ---
const src = dag.host().directory(".");

console.log("--- Lint container ---");
console.log(await lintContainer(src));

console.log("--- Lint YAML ---");
console.log(await lintYaml(src));

console.log("--- PHPUnit ---");
console.log(await phpUnit(src));
