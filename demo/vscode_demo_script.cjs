// Runs inside the VS Code extension host: the scripted part of the demo video.
const vscode = require("vscode");
const path = require("path");
const fs = require("fs");
const cp = require("child_process");

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LOG = process.env.SPB_DEMO_LOG;
const mark = (name) => fs.appendFileSync(LOG, `${name} ${Date.now()}\n`);
const ps = (cmd) => { try { return cp.execFileSync("powershell", ["-NoProfile", "-Command", cmd], { encoding: "utf8", timeout: 15000 }); } catch { return ""; } };
const killMsx = () => { try { cp.execSync("taskkill /IM openmsx.exe /F", { stdio: "ignore" }); } catch { /* not running */ } };
async function waitFor(fn, ms = 15000) { const t0 = Date.now(); for (;;) { const v = await fn(); if (v) return v; if (Date.now() - t0 > ms) return v; await sleep(200); } }

const FRONT = `Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class W{[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int c);[DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);}';
$p = Get-Process Code -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like '*Extension Development Host*' } | Select-Object -First 1;
if ($p) { [W]::ShowWindow($p.MainWindowHandle, 3) | Out-Null; [W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null }`;
const bringFront = () => ps(FRONT);
const MOVE = `Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class M{[DllImport("user32.dll")]public static extern bool MoveWindow(IntPtr h,int x,int y,int w,int ht,bool r);[DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int ht,uint f);}';
$p = Get-Process openmsx -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1;
if ($p) { [M]::SetWindowPos($p.MainWindowHandle, [IntPtr](-1), 800, 150, 660, 560, 0x40) | Out-Null }`;
const moveMsx = () => ps(MOVE);
async function placeMsx(ms) { const t0 = Date.now(); while (Date.now() - t0 < ms) { moveMsx(); await sleep(1500); } }

async function typeText(text, delay = 38) {
  for (const ch of text) {
    await vscode.commands.executeCommand("type", { text: ch });
    await sleep(ch === "\n" ? delay * 4 : delay);
  }
}

const PROGRAM = [
  "' Bouncing ball in SCREEN 1",
  "SCREEN 1",
  "COLOR 15, 4, 4",
  "CLS",
  "x = 2 : dx = 1",
  "DO",
  "    LOCATE 12, x : PRINT \" \";",
  "    x = x + dx",
  "    IF x > 30 OR x < 2 THEN dx = -dx",
  "    LOCATE 12, x : PRINT \"O\";",
  "    SLEEP 2",
  "LOOP",
  "",
].join("\n");

exports.run = async function run() {
  const ws = process.env.SPB_WS;
  await vscode.extensions.getExtension("fpracek.samprbasic").activate();
  await sleep(1500);
  bringFront();
  await sleep(1500);
  await vscode.commands.executeCommand("workbench.action.closeAuxiliaryBar");
  await vscode.commands.executeCommand("notifications.clearAll");
  await vscode.commands.executeCommand("workbench.action.closeAllEditors");
  const doc = await vscode.workspace.openTextDocument(path.join(ws, "DEMO.SPB"));
  const ed = await vscode.window.showTextDocument(doc);
  await sleep(2500);
  await vscode.commands.executeCommand("notifications.clearAll");
  mark("ready");

  // 1. typing, with live highlighting
  mark("typing");
  await typeText(PROGRAM);
  await sleep(1500);

  // 2. a compiler error appears as you type (the real compiler runs inside VS Code)
  mark("error");
  const sleepLine = PROGRAM.split("\n").findIndex((l) => l.includes("SLEEP 2"));
  const eol = new vscode.Position(sleepLine, "    SLEEP 2".length);
  await ed.edit((b) => b.insert(eol, " +"));
  await waitFor(() => vscode.languages.getDiagnostics(doc.uri).length, 8000);
  await sleep(3500);
  await ed.edit((b) => b.delete(new vscode.Range(eol, new vscode.Position(sleepLine, "    SLEEP 2 +".length))));
  await sleep(1500);

  // 3. hover help on a statement
  mark("hover");
  const locLine = PROGRAM.split("\n").findIndex((l) => l.includes("LOCATE 12, x : PRINT \"O\""));
  ed.selection = new vscode.Selection(locLine, 6, locLine, 6);
  ed.revealRange(new vscode.Range(locLine, 0, locLine, 0));
  await sleep(500);
  await vscode.commands.executeCommand("editor.action.showHover");
  await sleep(4500);
  await vscode.commands.executeCommand("closeParameterHints");
  await vscode.commands.executeCommand("workbench.action.focusActiveEditorGroup");
  ed.selection = new vscode.Selection(0, 0, 0, 0);
  await sleep(800);

  // 4. F5: compile and run in openMSX
  mark("run");
  await doc.save();
  await vscode.commands.executeCommand("samprbasic.run");
  await placeMsx(26000);
  mark("ran");
  killMsx();
  bringFront();
  await sleep(2500);

  // 5. debugger: breakpoint, stop, variables, stepping
  mark("debug");
  const bpLine = PROGRAM.split("\n").findIndex((l) => l.includes("x = x + dx"));
  vscode.debug.addBreakpoints([new vscode.SourceBreakpoint(new vscode.Location(doc.uri, new vscode.Position(bpLine, 0)))]);
  await sleep(1500);
  const started = await vscode.debug.startDebugging(undefined, { type: "samprbasic", request: "launch", name: "Demo", program: doc.fileName, stopOnEntry: false });
  const sess = () => vscode.debug.activeDebugSession;
  const frameAt = async () => { try { const st = await sess().customRequest("stackTrace", { threadId: 1 }); return st.stackFrames[0]; } catch { return undefined; } };
  const f1 = await waitFor(async () => { moveMsx(); const f = sess() ? await frameAt() : undefined; return f && f.line ? f : null; }, 180000);
  mark("stopped");
  moveMsx();
  await vscode.commands.executeCommand("notifications.clearAll");
  await sleep(1000);
  await vscode.commands.executeCommand("workbench.view.debug");
  await sleep(5000);
  for (let i = 0; i < 4; i++) {
    await vscode.commands.executeCommand("workbench.action.debug.stepOver");
    await sleep(2200);
  }
  mark("stepped");
  await vscode.commands.executeCommand("workbench.action.debug.continue");
  await sleep(3000);
  await vscode.commands.executeCommand("workbench.action.debug.pause");
  await sleep(3500);
  mark("paused");
  await vscode.debug.stopDebugging();
  killMsx();
  await sleep(1500);
  mark("end");
  if (!started || !f1) throw new Error("debugger did not stop at the breakpoint");
};
