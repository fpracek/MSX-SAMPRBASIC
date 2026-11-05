// End-to-end test of the ROM debugger: drives the Debug Adapter (src/debug.ts) over DAP against the 3-segment cartridge GEOMR.
const cp = require("child_process"), fs = require("fs"), os = require("os"), path = require("path"), { PassThrough } = require("stream");
const root = path.resolve(__dirname, "..");
const out = path.join(os.tmpdir(), "spb-dap-test.cjs");
cp.execSync(`node "${path.join(root, "node_modules", "esbuild", "bin", "esbuild")}" src/debug.ts --bundle --platform=node --format=cjs --outfile="${out}" --log-level=error`, { cwd: root });
const { SamprDebugSession } = require(out);

const OPENMSX = process.env.OPENMSX || "E:/Dropbox/FAUSTO/SVILUPPI/MSX/EMULATORI/openMSX/openmsx.exe";
const proj = fs.mkdtempSync(path.join(os.tmpdir(), "geomr-dap-"));
for (const n of ["GEOMR000", "GEOMR001", "GEOMR002"]) fs.writeFileSync(path.join(proj, n + ".SPB"), fs.readFileSync(path.join(root, "..", "sample_disk", n + ".SPB"), "latin1").replace(/\r?\n/g, "\r\n"), "latin1");
const prog = path.join(proj, "GEOMR000.SPB");

const session = new SamprDebugSession({ toolsDir: path.join(root, "tools"), extensionPath: root, cfg: () => ({ openmsx: OPENMSX, machine: "Philips_NMS_8250", extension: "", fullSpeed: true, dosFiles: "", askDate: false }) });
const input = new PassThrough(), output = new PassThrough();
session.start(input, output);
let seq = 1, buf = "";
const waiters = [], events = [], responses = new Map();
output.on("data", (d) => {
  buf += d.toString("latin1");
  for (;;) {
    const m = /^Content-Length: (\d+)\r\n\r\n/.exec(buf);
    if (!m) return;
    const n = parseInt(m[1], 10), start = m[0].length;
    if (buf.length < start + n) return;
    const msg = JSON.parse(Buffer.from(buf.slice(start, start + n), "latin1").toString("utf8"));
    buf = buf.slice(start + n);
    if (msg.type === "response") responses.get(msg.request_seq)?.(msg);
    else if (msg.type === "event") { events.push(msg); for (const w of waiters.slice()) w(msg); }
  }
});
const req = (command, args) => new Promise((res) => {
  const s = seq++;
  responses.set(s, res);
  const body = JSON.stringify({ seq: s, type: "request", command, arguments: args });
  input.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`);
});
const waitEvent = (name, ms = 60000) => new Promise((res, rej) => {
  const old = events.findIndex((e) => e.event === name);
  if (old >= 0) { res(events.splice(old, 1)[0]); return; }
  const t = setTimeout(() => rej(new Error("timeout waiting for " + name + " (events: " + events.map((e) => e.event) + ")")), ms);
  const w = (e) => { if (e.event === name) { clearTimeout(t); waiters.splice(waiters.indexOf(w), 1); events.splice(events.indexOf(e), 1); res(e); } };
  waiters.push(w);
});
let fails = 0;
const check = (name, ok, extra) => { console.log((ok ? "PASS " : "FAIL ") + name + (ok ? "" : "  -> " + JSON.stringify(extra))); if (!ok) fails++; };
const where = async () => {
  const st = await req("stackTrace", { threadId: 1 });
  const f = st.body.stackFrames[0];
  return { file: f && f.source && f.source.name, line: f && f.line, name: f && f.name };
};

(async () => {
  try {
    const lr = await req("launch", { program: prog, stopOnEntry: true });
    check("launch ok", lr.success, lr);
    await waitEvent("initialized");
    // breakpoints: a line in segment 1 (PLAYER_STEP body), one in segment 2 (MAKE_TILES), one in the main file
    const f1 = path.join(proj, "GEOMR001.SPB"), f2 = path.join(proj, "GEOMR002.SPB");
    const b1 = await req("setBreakpoints", { source: { path: f1 }, breakpoints: [{ line: 9 }] });
    const b2 = await req("setBreakpoints", { source: { path: f2 }, breakpoints: [{ line: 8 }] });
    const b0 = await req("setBreakpoints", { source: { path: prog }, breakpoints: [{ line: 79 }] });
    check("breakpoints verified", b1.body.breakpoints[0].verified && b2.body.breakpoints[0].verified && b0.body.breakpoints[0].verified, [b0.body, b1.body, b2.body]);
    await req("configurationDone", {});
    await waitEvent("stopped", 90000);
    let w = await where();
    check("stops on entry in the main file", w.file === "GEOMR000.SPB", w);
    const first = w.line;
    await req("next", { threadId: 1 });
    await waitEvent("stopped");
    w = await where();
    check("next moves on", w.file === "GEOMR000.SPB" && w.line >= first, w);
    // continue: the first breakpoint reached is the one in segment 2 (graphics generation at start-up)
    await req("continue", { threadId: 1 });
    await waitEvent("stopped", 90000);
    w = await where();
    check("breakpoint in segment 2", w.file === "GEOMR002.SPB" && w.line === 8 && /make_tiles/i.test(w.name), w);
    const sc = await req("scopes", { frameId: 1 });
    const loc = await req("variables", { variablesReference: sc.body.scopes[0].variablesReference });
    check("locals of make_tiles", loc.body.variables.some((v) => /^a$/i.test(v.name)), loc.body);
    const glob = await req("variables", { variablesReference: sc.body.scopes[sc.body.scopes.length - 1].variablesReference });
    check("globals read", glob.body.variables.length > 10, glob.body.variables.length);
    // step into CALL tile (segment 1) from segment 2
    await req("continue", { threadId: 1 });
    await waitEvent("stopped", 90000);
    w = await where();
    check("then the breakpoint in the main file", w.file === "GEOMR000.SPB" && w.line === 79, w);
    await req("setBreakpoints", { source: { path: prog }, breakpoints: [] });
    await req("continue", { threadId: 1 });
    await waitEvent("stopped", 90000);
    w = await where();
    check("breakpoint in segment 1 (game loop)", w.file === "GEOMR001.SPB" && /scene/i.test(w.name), w);
    await req("stepOut", { threadId: 1 });
    await waitEvent("stopped", 30000);
    w = await where();
    check("step out returns to the main file", w.file === "GEOMR000.SPB", w);
  } catch (e) {
    console.log("ERROR", e && e.message || e);
    fails++;
  }
  try { await req("disconnect", {}); } catch (e) { /* ignore */ }
  console.log(fails ? `${fails} FAILED` : "ALL PASSED");
  process.exit(fails ? 1 : 0);
})();
