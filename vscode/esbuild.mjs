import * as esbuild from "esbuild";
const watch = process.argv.includes("--watch");
const common = { bundle: true, platform: "node", target: "node20", sourcemap: true, logLevel: "info" };
const builds = [
  { ...common, entryPoints: ["src/lib.ts"], outfile: "dist/compile.cjs", format: "cjs" },
];
import { existsSync } from "fs";
if (existsSync("src/extension.ts")) builds.push({ ...common, entryPoints: ["src/extension.ts"], outfile: "dist/extension.js", format: "cjs", external: ["vscode"] });
for (const b of builds) {
  if (watch) { const c = await esbuild.context(b); await c.watch(); } else await esbuild.build(b);
}
