// Runs the extension tests inside a real VS Code (the installed one, no download).
const path = require("path");
const fs = require("fs");
const os = require("os");
const { runTests } = require("@vscode/test-electron");

(async () => {
  const root = path.resolve(__dirname, "..", "..");
  const exe = process.env.VSCODE_EXE || path.join(process.env.LOCALAPPDATA || "", "Programs", "Microsoft VS Code", "Code.exe");
  const ws = fs.mkdtempSync(path.join(os.tmpdir(), "spb-ws-"));
  fs.writeFileSync(path.join(ws, "BAD.SPB"), 'PRINT "a"\r\nPRINT "b"\r\nPRINT 1 +\r\nPRINT "c"\r\n');
  fs.writeFileSync(path.join(ws, "GOOD.SPB"), 'PRINT "ok"\r\nSUB hello(n)\r\n  PRINT n\r\nEND SUB\r\nCALL hello(5)\r\nloop1:\r\n');
  fs.writeFileSync(path.join(ws, "TEMP.SPB"), 'PRINT "x"\r\n');
  const data = fs.mkdtempSync(path.join(os.tmpdir(), "spb-data-"));
  const exts = fs.mkdtempSync(path.join(os.tmpdir(), "spb-exts-"));
  try {
    await runTests({
      vscodeExecutablePath: exe,
      extensionDevelopmentPath: root,
      extensionTestsPath: path.resolve(__dirname, "index.cjs"),
      launchArgs: [ws, "--disable-extensions", "--user-data-dir", data, "--extensions-dir", exts, "--disable-workspace-trust"],
      extensionTestsEnv: { SPB_WS: ws },
    });
  } catch (e) {
    console.error("Extension tests failed:", e);
    process.exit(1);
  }
})();
