// Executed inside the VS Code extension host.
const vscode = require("vscode");
const path = require("path");
const fs = require("fs");

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function waitFor(fn, ms = 15000) { const t0 = Date.now(); for (;;) { const v = await fn(); if (v) return v; if (Date.now() - t0 > ms) return v; await sleep(200); } }
let fails = 0;
const check = (c, m) => { console.log((c ? "  ok   " : "  FAIL ") + m); if (!c) fails++; };

exports.run = async function run() {
  const ws = process.env.SPB_WS;
  const ext = vscode.extensions.getExtension("fpracek.samprbasic");
  check(!!ext, "extension found");
  await ext.activate();

  // language, syntax errors from the real compiler
  const bad = await vscode.workspace.openTextDocument(path.join(ws, "BAD.SPB"));
  await vscode.window.showTextDocument(bad);
  check(bad.languageId === "samprbasic", "language id of .spb is samprbasic");
  const diags = await waitFor(() => { const d = vscode.languages.getDiagnostics(bad.uri); return d.length ? d : null; });
  check(!!diags && diags.length === 1 && diags[0].range.start.line === 2, "syntax error on line 3: " + JSON.stringify((diags || []).map((d) => [d.range.start.line + 1, d.message])));

  // unsaved edits are compiled too: fix the line in the buffer
  const ed = vscode.window.activeTextEditor;
  await ed.edit((b) => b.replace(new vscode.Range(2, 0, 2, 9), "PRINT 1 + 2"));
  const cleared = await waitFor(() => (vscode.languages.getDiagnostics(bad.uri).length === 0 ? true : null));
  check(!!cleared, "diagnostic disappears after fixing the (unsaved) text");

  // hover, symbols
  const good = await vscode.workspace.openTextDocument(path.join(ws, "GOOD.SPB"));
  await vscode.window.showTextDocument(good);
  const hovers = await vscode.commands.executeCommand("vscode.executeHoverProvider", good.uri, new vscode.Position(0, 2));
  const htxt = (hovers || []).map((h) => h.contents.map((c) => c.value || String(c)).join("")).join("");
  check(/PRINT/.test(htxt) && /screen/i.test(htxt), "hover on PRINT shows its help: " + htxt.slice(0, 200));
  const syms = await vscode.commands.executeCommand("vscode.executeDocumentSymbolProvider", good.uri);
  const names = (syms || []).map((s) => s.name);
  check(names.includes("hello") && names.includes("loop1"), "outline lists SUB and label: " + names.join(","));

  // build writes the program next to the source
  await vscode.window.showTextDocument(good);
  await vscode.commands.executeCommand("samprbasic.build");
  const out = path.join(ws, "GOOD.COM");
  const okOut = await waitFor(() => (fs.existsSync(out) ? true : null), 8000);
  check(!!okOut, "GOOD.COM written in the project folder");

  // compile error from the build command opens the offending line
  const bad2 = await vscode.workspace.openTextDocument(path.join(ws, "BAD.SPB"));
  const e2 = await vscode.window.showTextDocument(bad2);
  await e2.edit((b) => b.replace(new vscode.Range(2, 0, 2, 11), "PRINT 1 +"));
  await bad2.save();
  await vscode.commands.executeCommand("samprbasic.build");
  const d2 = vscode.languages.getDiagnostics(bad2.uri);
  check(d2.length === 1 && d2[0].range.start.line === 2, "build reports the error on the right line");

  // about / help index commands exist
  const cmds = await vscode.commands.getCommands(true);
  for (const c of ["samprbasic.run", "samprbasic.helpWord", "samprbasic.helpIndex", "samprbasic.segment", "samprbasic.about", "samprbasic.newProject"]) check(cmds.includes(c), "command " + c);

  if (fails) throw new Error(`${fails} check(s) failed`);
};
