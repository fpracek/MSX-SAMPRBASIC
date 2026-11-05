// Compiles the 3-segment ROM version (sample_disk/GEOMR00x.SPB) and runs it in openMSX; dumps VRAM at given times.
const fs = require("fs"), path = require("path"), os = require("os");
const lib = require(path.resolve(__dirname, "..", "vscode", "dist", "compile.cjs"));
const OPENMSX = process.env.OPENMSX || "E:/Dropbox/FAUSTO/SVILUPPI/MSX/EMULATORI/openMSX/openmsx.exe";
const tools = path.resolve(__dirname, "..", "vscode", "tools");
const d = fs.mkdtempSync(path.join(os.tmpdir(), "geomrom-"));
for (const n of ["GEOMR000", "GEOMR001", "GEOMR002"]) fs.writeFileSync(path.join(d, n + ".SPB"), fs.readFileSync(path.resolve(__dirname, "..", "sample_disk", n + ".SPB"), "latin1").replace(/\r?\n/g, "\r\n"), "latin1");
const r = lib.compile(d, tools, "GEOMR000.SPB");
console.log(JSON.stringify({ ok: r.ok, out: r.output, diag: r.diagnostics }));
if (!r.ok) process.exit(1);
const log = (process.env.LOG || path.join(os.tmpdir(), "geomrom.txt")).split(path.sep).join("/");
try { fs.unlinkSync(log); } catch (e) {}
const dump = (t) => `after time ${t} {set f [open "${log}" a]; binary scan [debug read_block VRAM 6240 28] c* d; set s ""; foreach b $d {set b [expr {$b & 255}]; if {$b>=32 && $b<127} {append s [format %c $b]} else {append s .}}; binary scan [debug read_block VRAM 6145 12] c* e; set s2 ""; foreach b $e {set b [expr {$b & 255}]; if {$b>=32 && $b<127} {append s2 [format %c $b]} else {append s2 .}}; binary scan [debug read_block VRAM 7680 24] c* a; puts $f "${t} row3=$s hud=$s2 attr=$a"; close $f}\n`;
const times = (process.env.TIMES || "20,30,40,50,60").split(",").map(Number);
let tcl = "after time 5 {set throttle off; set minframeskip 0; set maxframeskip 0}\n";
times.forEach((t) => { tcl += dump(t); });
for (const k of (process.env.KEYS || "").split(";").filter(Boolean)) { const [t, row, mask, t2] = k.split(":"); tcl += `after time ${t} {keymatrixdown ${row} ${mask}}\nafter time ${t2} {keymatrixup ${row} ${mask}}\n`; }
tcl += (process.env.EXTRA_TCL || "") + `after time ${Math.max(...times) + 2} {exit}\n`;
process.env.SPB_TEST_TCL = tcl;
const res = lib.launchRom({ openmsx: OPENMSX, machine: "Philips_NMS_8250", extension: "", fullSpeed: true, dosFiles: "", askDate: false }, path.join(d, r.output), fs.readFileSync(path.join(d, "GEOMR000.SPB"), "latin1"));
console.log("launched", typeof res === "string" ? res : "ok");
setTimeout(() => { console.log(fs.existsSync(log) ? fs.readFileSync(log, "utf8") : "no log"); process.exit(0); }, 150000);
