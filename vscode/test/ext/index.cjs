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


  // ---- debugger (openMSX)
  const dbgDoc = await vscode.workspace.openTextDocument(path.join(ws, "DBG.SPB"));
  await vscode.window.showTextDocument(dbgDoc);
  vscode.debug.addBreakpoints([new vscode.SourceBreakpoint(new vscode.Location(dbgDoc.uri, new vscode.Position(9, 0)))]); // line 10: PRINT q (inside the SUB)
  const started = await vscode.debug.startDebugging(undefined, { type: "samprbasic", request: "launch", name: "t", program: dbgDoc.fileName, stopOnEntry: false });
  check(started, "debug session started");
  const sess = () => vscode.debug.activeDebugSession;
  const frameAt = async () => { try { const st = await sess().customRequest("stackTrace", { threadId: 1 }); return st.stackFrames[0]; } catch { return undefined; } };
  const f1 = await waitFor(async () => { const f = sess() ? await frameAt() : undefined; return f && f.line ? f : null; }, 120000);
  check(!!f1 && f1.line === 10, "stopped at the breakpoint on line 10: " + JSON.stringify(f1 && [f1.name, f1.line]));
  check(!!f1 && /SUB prova/.test(f1.name), "frame is named after the SUB");
  const getVars = async () => {
    const sc = await sess().customRequest("scopes", { frameId: 1 });
    const out = {};
    for (const s of sc.scopes) { const v = await sess().customRequest("variables", { variablesReference: s.variablesReference }); out[s.name] = Object.fromEntries(v.variables.map((x) => [x.name, x.value])); }
    return out;
  };
  const v1 = await getVars();
  check(v1.Locals && v1.Locals.p === "8" && v1.Locals.q === "16" && v1.Locals["s$"] === '"arg"', "locals: " + JSON.stringify(v1.Locals));
  check(v1.Globals && v1.Globals.g === "7" && v1.Globals["n$"] === '"hi"', "globals: " + JSON.stringify(v1.Globals));
  const ev = await sess().customRequest("evaluate", { expression: "v(2)", context: "watch" });
  check(ev.result === "42", "evaluate v(2) = " + ev.result);
  await sess().customRequest("stepOut", { threadId: 1 });
  const f2 = await waitFor(async () => { const f = await frameAt(); return f && f.line && f.line !== 10 ? f : null; }, 60000);
  check(!!f2 && f2.line === 7, "step out of the SUB stops on line 7: " + JSON.stringify(f2 && [f2.name, f2.line]));
  await vscode.debug.stopDebugging();

  // about / help index commands exist
  const cmds = await vscode.commands.getCommands(true);
  for (const c of ["samprbasic.run", "samprbasic.helpWord", "samprbasic.helpIndex", "samprbasic.segment", "samprbasic.about", "samprbasic.newProject"]) check(cmds.includes(c), "command " + c);

  if (fails) throw new Error(`${fails} check(s) failed`);
};
