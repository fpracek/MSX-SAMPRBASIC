// Records the VS Code side of the demo: real VS Code (extension development host) driven by vscode_demo_script.cjs,
// screen captured with ffmpeg (gdigrab).
const path = require("path");
const fs = require("fs");
const os = require("os");
const cp = require("child_process");
const { runTests } = require(path.resolve(__dirname, "..", "vscode", "node_modules", "@vscode", "test-electron"));

const FF = fs.readFileSync(path.join(__dirname, "ffpath.txt"), "utf8").trim();
const root = path.resolve(__dirname, "..", "vscode");
const exe = process.env.VSCODE_EXE || path.join(process.env.LOCALAPPDATA || "", "Programs", "Microsoft VS Code", "Code.exe");
const OUT = path.join(__dirname, "vscode_raw.mp4");
const LOG = path.join(__dirname, "vscode_marks.txt");
try { fs.unlinkSync(LOG); } catch { /* none */ }
try { fs.unlinkSync(OUT); } catch { /* none */ }

(async () => {
  const ws = fs.mkdtempSync(path.join(os.tmpdir(), "spb-demo-ws-"));
  fs.writeFileSync(path.join(ws, "DEMO.SPB"), "");
  fs.mkdirSync(path.join(ws, ".vscode"), { recursive: true });
  fs.writeFileSync(path.join(ws, ".vscode", "settings.json"), JSON.stringify({
    "samprbasic.openmsx.path": process.env.OPENMSX || "E:/Dropbox/FAUSTO/SVILUPPI/MSX/EMULATORI/openMSX/openmsx.exe",
    "samprbasic.dosFiles": process.env.SPB_DOS || "E:/Dropbox/FAUSTO/SVILUPPI/MSX/DISK2",
    "workbench.colorTheme": "SamPr Basic MSX",
    "workbench.startupEditor": "none",
    "editor.minimap.enabled": false,
    "editor.autoIndent": "none",
    "editor.autoClosingQuotes": "never",
    "chat.disableAIFeatures": true,
    "workbench.secondarySideBar.defaultVisibility": "hidden",
    "window.commandCenter": false,
    "extensions.ignoreRecommendations": true,
    "editor.fontSize": 17,
    "window.zoomLevel": 0,
    "workbench.tips.enabled": false,
    "workbench.layoutControl.enabled": false,
    "files.autoSave": "off",
    "editor.quickSuggestions": false,
    "editor.suggestOnTriggerCharacters": false,
  }, null, 2));
  const data = fs.mkdtempSync(path.join(os.tmpdir(), "spb-data-"));
  const exts = fs.mkdtempSync(path.join(os.tmpdir(), "spb-exts-"));

  const ff = cp.spawn(FF, ["-y", "-f", "gdigrab", "-framerate", "25", "-i", "desktop", "-c:v", "libx264", "-preset", "ultrafast", "-crf", "20", "-pix_fmt", "yuv420p", OUT], { stdio: ["pipe", "ignore", "pipe"] });
  let started = 0;
  ff.stderr.on("data", (d) => { if (!started && /frame=/.test(String(d))) { started = Date.now(); fs.appendFileSync(LOG, `ffmpeg ${started}\n`); } });
  await new Promise((r) => setTimeout(r, 2000));
  let failed = false;
  try {
    await runTests({
      vscodeExecutablePath: exe,
      extensionDevelopmentPath: root,
      extensionTestsPath: path.join(__dirname, "vscode_demo_script.cjs"),
      launchArgs: [ws, "--disable-extensions", "--user-data-dir", data, "--extensions-dir", exts, "--disable-workspace-trust", "--new-window"],
      extensionTestsEnv: { SPB_WS: ws, SPB_DEMO_LOG: LOG },
    });
  } catch (e) {
    console.error("demo script failed:", e);
    failed = true;
  }
  fs.appendFileSync(LOG, `finished ${Date.now()}\n`);
  ff.stdin.write("q");
  await new Promise((r) => ff.on("exit", r));
  console.log(failed ? "FAILED" : "recorded", OUT, fs.existsSync(OUT) ? fs.statSync(OUT).size : "missing");
  console.log(fs.readFileSync(LOG, "utf8"));
})();
