#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

if (process.platform !== "darwin") {
  console.error("Backpack Awake can only be installed on macOS.");
  process.exit(1);
}

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const installer = resolve(packageRoot, "install.sh");

const result = spawnSync("/bin/zsh", [installer], {
  cwd: packageRoot,
  env: {
    ...process.env,
    BACKPACK_AWAKE_SOURCE_DIR: packageRoot,
  },
  stdio: "inherit",
});

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}

process.exit(result.status ?? 1);
