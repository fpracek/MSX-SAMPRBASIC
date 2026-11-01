// End-to-end: compile with the extension library, launch openMSX like the extension does, read the screen.
const fs = require("fs"), path = require("path"), os = require("os");
const lib = require("../dist/compile.cjs");
const OPENMSX = process.env.OPENMSX || "E:/Dropbox/FAUSTO/SVILUPPI/MSX/EMULATORI/openMSX/openmsx.exe";
const DOS = process.env.SPB_DOS || "E:/Dropbox/FAUSTO/SVILUPPI/MSX/DISK2";
let fails = 0;
const check = (c, m) => { console.log((c ? "  ok   " : "  FAIL ") + m); if (!c) fails++; };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const tmp = (p) => fs.mkdtempSync(path.join(os.tmpdir(), p));
const dumpTcl = (out, cols, rows, at) => `
after time ${at} {
  set f [open "${out.split(path.sep).join("/")}" w]
  binary scan [debug read_block VRAM 0 ${cols * rows}] c* b
  set row ""; set n 0
  foreach x $b { set x [expr {$x & 255}]; if {$x < 32 || $x > 126} {set x 46}; append row [format %c $x]; incr n; if {$n == ${cols}} {puts $f $row; set row ""; set n 0} }
  close $f
  exit
}
`;
async function waitFile(p, ms) { for (let t = 0; t < ms; t += 500) { if (fs.existsSync(p)) { await sleep(500); return fs.readFileSync(p, "utf8"); } await sleep(500); } return ""; }
const cfg = (extra = {}) => ({ openmsx: OPENMSX, machine: "Philips_NMS_8250", extension: "", fullSpeed: true, dosFiles: DOS, askDate: false, ...extra });
const CRLF = "\r\n";

(async () => {
  // --- BIN (the screen is read in real time: a stray host key event can end the program, so one retry is allowed)
  console.log("--- BIN (MSX-BASIC)");
  let d = tmp("e2e-bin-");
  fs.writeFileSync(path.join(d, "BT.SPB"), ["OPTION TARGET BIN", 'PRINT "ciao bin"', "PRINT 6 * 7", ""].join(CRLF));
  let r = lib.compile(d, "tools", "BT.SPB");
  check(r.ok && r.kind === "bin", "compiled: " + JSON.stringify([r.ok, r.kind, r.output]));
  let out, scr = "";
  for (let attempt = 0; attempt < 2 && !(/ciao bin/.test(scr) && /\b42\b/.test(scr)); attempt++) {
    out = path.join(tmp("e2e-out-"), "scr.txt");
    process.env.SPB_TEST_TCL = "set throttle off\n" + dumpTcl(out, 40, 24, 45);
    lib.launchBin(cfg(), path.join(d, r.output));
    scr = await waitFile(out, 120000);
  }
  check(/ciao bin/.test(scr) && /\b42\b/.test(scr), "screen shows the output: " + scr.split("\n").slice(0, 4).join(" / "));

  // --- DOS
  console.log("--- DOS");
  d = tmp("e2e-dos-");
  fs.writeFileSync(path.join(d, "HELLO.SPB"), ['PRINT "dos ok"', "PRINT 6 * 7", ""].join(CRLF));
  r = lib.compile(d, "tools", "HELLO.SPB");
  check(r.ok && r.kind === "dos" && r.output === "HELLO.COM", "compiled: " + JSON.stringify([r.ok, r.kind, r.output]));
  out = path.join(tmp("e2e-out-"), "scr.txt");
  process.env.SPB_TEST_TCL = "after time 30 {set throttle off}\n" + dumpTcl(out, 80, 24, 60);
  const res = lib.launchDos(cfg(), d, path.join(d, r.output));
  check(typeof res !== "string", "launched");
  scr = await waitFile(out, 120000);
  check(/dos ok/.test(scr) && /\b42\b/.test(scr), "screen shows the output: " + scr.split("\n").slice(0, 8).join(" / ").slice(0, 160));

  // --- ROM (two files + a BIN segment)
  console.log("--- multi-file ROM");
  d = tmp("e2e-rom-");
  fs.writeFileSync(path.join(d, "FAUST000.SPB"), ["OPTION TARGET ROM_KONAMISCC", 'PRINT "main"', "CALL FAR hello(3)", "PRINT twice(21)", "END", ""].join(CRLF));
  fs.writeFileSync(path.join(d, "FAUST001.SPB"), ["SUB hello(n)", '  PRINT "hello from seg1:"; n', "END SUB", "FUNCTION twice(x)", "  twice = x * 2", "END FUNCTION", ""].join(CRLF));
  fs.writeFileSync(path.join(d, "FAUST002.BIN"), Buffer.from([1, 2, 3]));
  r = lib.compile(d, "tools", "FAUST001.SPB"); // from a segment file: the compiler goes to FAUST000
  check(r.ok && r.kind === "rom", "compiled: " + JSON.stringify([r.ok, r.kind, r.output, r.diagnostics]));
  out = path.join(tmp("e2e-out-"), "scr.txt");
  process.env.SPB_TEST_TCL = "set throttle off\n" + dumpTcl(out, 80, 24, 16);
  lib.launchRom(cfg(), path.join(d, r.output), fs.readFileSync(path.join(d, "FAUST000.SPB"), "latin1"));
  scr = await waitFile(out, 90000);
  check(/main/.test(scr) && /hello from seg1: *3/.test(scr) && /\b42\b/.test(scr), "screen shows the output: " + scr.split("\n").slice(0, 4).join(" / "));
  console.log(fails ? `FAILED: ${fails}` : "ALL OK");
  process.exit(fails ? 1 : 0);
})();
