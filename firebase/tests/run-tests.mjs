import { createServer } from "net";
import { writeFileSync, unlinkSync } from "fs";
import { resolve } from "path";
import { spawn } from "child_process";

function findFreePort() {
  return new Promise((resolvePort, reject) => {
    const server = createServer();
    server.unref();
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (!address || typeof address === "string") {
        server.close(() => reject(new Error("Could not resolve a free port.")));
        return;
      }
      const port = address.port;
      server.close(() => resolvePort(port));
    });
  });
}

async function main() {
  const port = await findFreePort();
  const firebaseRoot = resolve(process.cwd(), "..");
  const tempConfigPath = resolve(firebaseRoot, "tests", "firebase.temp.json");

  const tempConfig = {
    firestore: { rules: "firestore.rules" },
    emulators: {
      firestore: { port },
      ui: { enabled: false },
    },
  };

  writeFileSync(tempConfigPath, JSON.stringify(tempConfig, null, 2));

  const cmd = `firebase emulators:exec --project nexiva-test --config ./tests/firebase.temp.json --only firestore \"cd tests && npx vitest run\"`;
  const child = spawn(cmd, {
    cwd: firebaseRoot,
    shell: true,
    stdio: "inherit",
  });

  child.on("close", (code) => {
    try {
      unlinkSync(tempConfigPath);
    } catch {
      // Best-effort cleanup.
    }
    process.exit(code ?? 1);
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
