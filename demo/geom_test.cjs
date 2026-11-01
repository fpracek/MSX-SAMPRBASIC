// Compiles sample_disk/GEOMRUN.SPB with the extension library and runs it in openMSX, taking screenshots.
const fs = require("fs"), path = require("path"), os = require("os");
const lib = require(path.resolve(__dirname, "..", "vscode", "dist", "compile.cjs"));
const OPENMSX = process.env.OPENMSX || "E:/Dropbox/FAUSTO/SVILUPPI/MSX/EMULATORI/openMSX/openmsx.exe";
const DOS = process.env.SPB_DOS || "E:/Dropbox/FAUSTO/SVILUPPI/MSX/DISK2";
const tools = path.resolve(__dirname, "..", "vscode", "tools");
const out = path.join(__dirname, "shots");
fs.mkdirSync(out, { recursive: true });
for (const f of fs.readdirSync(out)) fs.unlinkSync(path.join(out, f));
const d = fs.mkdtempSync(path.join(os.tmpdir(), "geom-"));
const src = fs.readFileSync(process.env.SRC || path.resolve(__dirname, "..", "sample_disk", "GEOMRUN.SPB"), "latin1").replace(/\r?\n/g, "\r\n");
fs.writeFileSync(path.join(d, "GEOMRUN.SPB"), src, "latin1");
const r = lib.compile(d, tools, "GEOMRUN.SPB");
console.log(JSON.stringify({ ok: r.ok, out: r.output, diag: r.diagnostics, console: r.console }));
if (!r.ok) process.exit(1);
const o = out.split(path.sep).join("/");
const times = (process.env.SHOTS || "40,48,56,64,72,80").split(",").map(Number);
let tcl = "after time 25 {set throttle off; set minframeskip 0; set maxframeskip 0}\n";
times.forEach((t, i) => { tcl += `after time ${t} {screenshot "${o}/s${i}_${t}.png"}\n`; });
const keys = process.env.KEYS || "";   // "t:row:mask:t2" -> keymatrixdown at t, up at t2
for (const k of keys.split(";").filter(Boolean)) {
  const [t, row, mask, t2] = k.split(":");
  tcl += `after time ${t} {keymatrixdown ${row} ${mask}}\nafter time ${t2} {keymatrixup ${row} ${mask}}\n`;
}
tcl += (process.env.EXTRA_TCL || "") + `after time ${Math.max(...times) + 3} {exit}\n`;
process.env.SPB_TEST_TCL = tcl;
const res = lib.launchDos({ openmsx: OPENMSX, machine: "Philips_NMS_8250", extension: "", fullSpeed: true, dosFiles: DOS, askDate: false }, d, path.join(d, r.output));
console.log("launched", typeof res === "string" ? res : "ok");
setTimeout(() => { console.log(fs.readdirSync(out).join(" ")); process.exit(0); }, 120000);
