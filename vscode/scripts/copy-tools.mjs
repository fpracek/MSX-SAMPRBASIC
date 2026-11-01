// Copies the compiler, the runtimes and the help from the project's dist folder into the extension (tools/).
import { copyFileSync, mkdirSync, readdirSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, "..", "..", "dist");
const tools = join(here, "..", "tools");
const samples = join(here, "..", "samples");
mkdirSync(tools, { recursive: true });
mkdirSync(samples, { recursive: true });
const toolFiles = ["QBC.COM", "QBCR.COM", "QBCB.COM", "RT.BIN", "RTD.BIN", "RTROM.BIN", "RTROMD.BIN", "RTBIN.BIN", "QASM.OVL", "SAMPRBAS.COM"];
for (const f of toolFiles) copyFileSync(join(dist, f), join(tools, f));
for (const f of readdirSync(dist)) if (f.toUpperCase().endsWith(".SPB")) copyFileSync(join(dist, f), join(samples, f));
console.log("tools copied:", toolFiles.length, "samples:", readdirSync(samples).length);
