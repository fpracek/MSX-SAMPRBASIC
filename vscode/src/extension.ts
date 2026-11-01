// SamPr Basic for MSX - VS Code extension. Same workflow and the same files as the editor that runs on the MSX.
import * as vscode from "vscode";
import * as fs from "fs";
import * as path from "path";
import { compile, CompileResult } from "./compile";
import { launchBin, launchDos, launchRom, LaunchConfig } from "./openmsx";

interface HelpTopic { names: string[]; category: string; syntax: string[]; description: string; example: string | null; see: string[]; availability: string; }

let diagnostics: vscode.DiagnosticCollection;
let output: vscode.OutputChannel;
let helpTopics: HelpTopic[] = [];
let statusItem: vscode.StatusBarItem;
let extPath = "";

const ABOUT = "SamPr Basic 1.0\n2026 Fausto Pracek";
const toolsDir = () => path.join(extPath, "tools");

// ---------------------------------------------------------------- MSX file names and projects
/** "NAME" + 3 digits (5 characters + 3 digits): a segment of a multi-file cartridge. */
const SEGMENT_RE = /^(.{5})(\d{3})$/;

function baseName(file: string): string { return path.basename(file, path.extname(file)); }

/** The file the compiler must start from: the document itself (the compiler redirects NAME001 to NAME000 when needed). */
function projectFileOf(doc: vscode.TextDocument): { dir: string; file: string } {
  return { dir: path.dirname(doc.fileName), file: path.basename(doc.fileName).toUpperCase() };
}

function encodeMsx(text: string): Uint8Array {
  const s = text.replace(/\r?\n/g, "\r\n");
  const out = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i) & 0xff;
  return out;
}

function overridesFor(dir: string): Map<string, Uint8Array> {
  const m = new Map<string, Uint8Array>();
  for (const d of vscode.workspace.textDocuments) {
    if (d.isDirty && d.languageId === "samprbasic" && path.dirname(d.fileName).toLowerCase() === dir.toLowerCase()) {
      m.set(path.basename(d.fileName).toUpperCase(), encodeMsx(d.getText()));
    }
  }
  return m;
}

// ---------------------------------------------------------------- diagnostics
function publish(result: CompileResult, dir: string): void {
  diagnostics.clear();
  const byFile = new Map<string, vscode.Diagnostic[]>();
  for (const d of result.diagnostics) {
    const full = findFile(dir, d.file);
    const key = full ?? path.join(dir, d.file);
    const line = Math.max(0, d.line - 1);
    const range = new vscode.Range(line, 0, line, Number.MAX_SAFE_INTEGER);
    const diag = new vscode.Diagnostic(range, `${d.message} (error ${d.code})`, vscode.DiagnosticSeverity.Error);
    diag.source = "SamPr Basic";
    const arr = byFile.get(key) ?? [];
    arr.push(diag);
    byFile.set(key, arr);
  }
  for (const [file, arr] of byFile) diagnostics.set(vscode.Uri.file(file), arr);
}

function findFile(dir: string, name: string): string | undefined {
  try {
    const up = name.toUpperCase();
    for (const f of fs.readdirSync(dir)) if (f.toUpperCase() === up) return path.join(dir, f);
  } catch { /* ignore */ }
  return undefined;
}

let liveTimer: NodeJS.Timeout | undefined;
function scheduleLive(doc: vscode.TextDocument): void {
  if (doc.languageId !== "samprbasic" || doc.uri.scheme !== "file") return;
  if (liveTimer) clearTimeout(liveTimer);
  liveTimer = setTimeout(() => {
    const { dir, file } = projectFileOf(doc);
    try {
      const r = compile(dir, toolsDir(), file, { overrides: overridesFor(dir), dryRun: true });
      publish(r, dir);
      statusItem.text = r.ok ? "$(check) SamPr Basic" : `$(error) SamPr Basic: ${r.diagnostics.length}`;
    } catch (e) {
      statusItem.text = "$(warning) SamPr Basic";
      output.appendLine(String(e));
    }
  }, 500);
}

// ---------------------------------------------------------------- build and run
async function saveCurrent(): Promise<vscode.TextDocument | undefined> {
  const ed = vscode.window.activeTextEditor;
  if (!ed || ed.document.languageId !== "samprbasic") { vscode.window.showWarningMessage("Open a SamPr Basic (.spb) file first."); return undefined; }
  if (ed.document.isUntitled) {
    vscode.window.showWarningMessage("Save the file first (up to 8 characters + .SPB), as on the MSX.");
    await vscode.commands.executeCommand("workbench.action.files.saveAs");
    return ed.document.isUntitled ? undefined : ed.document;
  }
  if (ed.document.isDirty) await ed.document.save();
  return ed.document;
}

function build(doc: vscode.TextDocument): CompileResult {
  const { dir, file } = projectFileOf(doc);
  output.clear();
  const t0 = Date.now();
  const r = compile(dir, toolsDir(), file);
  publish(r, dir);
  if (r.ok) output.appendLine(`Compiled ${file} -> ${r.output} in ${Date.now() - t0} ms`);
  else for (const d of r.diagnostics) output.appendLine(`${d.file}:${d.line}: error ${d.code}: ${d.message}`);
  return r;
}

function launchCfg(): LaunchConfig {
  const c = vscode.workspace.getConfiguration("samprbasic");
  return {
    openmsx: c.get<string>("openmsx.path", ""), machine: c.get<string>("machine", "Philips_NMS_8250"), extension: c.get<string>("extension", ""),
    fullSpeed: c.get<boolean>("fullSpeedWhenLoading", true), dosFiles: c.get<string>("dosFiles", ""), askDate: c.get<boolean>("askDate", false),
  };
}

async function cmdBuild(): Promise<void> {
  const doc = await saveCurrent();
  if (!doc) return;
  const r = build(doc);
  if (r.ok) vscode.window.setStatusBarMessage(`SamPr Basic: ${r.output} written`, 4000);
  else {
    const d = r.diagnostics[0];
    vscode.window.showErrorMessage(`${d.file} line ${d.line}: ${d.message}`);
    output.show(true);
    const f = findFile(path.dirname(doc.fileName), d.file);
    if (f) {
      const ed = await vscode.window.showTextDocument(vscode.Uri.file(f));
      const pos = new vscode.Position(Math.max(0, d.line - 1), 0);
      ed.selection = new vscode.Selection(pos, pos);
      ed.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);
    }
  }
}

async function cmdRun(): Promise<void> {
  const doc = await saveCurrent();
  if (!doc) return;
  const r = build(doc);
  if (!r.ok) { await cmdBuild(); return; }
  const dir = path.dirname(doc.fileName);
  const cfg = launchCfg();
  const out = findFile(dir, r.output!);
  if (!out) { vscode.window.showErrorMessage(`${r.output} was not found after compiling.`); return; }
  try {
    if (r.kind === "rom") {
      const main = findFile(dir, path.basename(doc.fileName).replace(/\d{3}(\.\w+)$/, "000$1")) ?? doc.fileName;
      launchRom(cfg, out, fs.readFileSync(main, "latin1"));
    } else if (r.kind === "bin") launchBin(cfg, out);
    else {
      const res = launchDos(cfg, dir, out);
      if (typeof res === "string") {
        const pick = await vscode.window.showWarningMessage(res, "Open Settings");
        if (pick) vscode.commands.executeCommand("workbench.action.openSettings", "samprbasic.dosFiles");
      }
    }
  } catch (e) {
    vscode.window.showErrorMessage(`Cannot start openMSX: ${e}. Set 'samprbasic.openmsx.path'.`);
  }
}

// ---------------------------------------------------------------- help (F6 / F7)
function loadHelp(): void {
  try { helpTopics = JSON.parse(fs.readFileSync(path.join(extPath, "data", "help.json"), "utf8")); } catch { helpTopics = []; }
}

function findTopic(word: string): HelpTopic | undefined {
  const w = word.toUpperCase().replace(/\$$/, (m) => m);
  return helpTopics.find((t) => t.names.some((n) => n.toUpperCase() === w)) ?? helpTopics.find((t) => t.names.some((n) => n.toUpperCase() === w.replace(/\$$/, "")));
}

function topicText(t: HelpTopic): string {
  let s = `${t.names[0]}\n${"-".repeat(t.names[0].length)}\n\n${t.syntax.join("\n")}\n\n${t.description}\n`;
  if (t.example) s += `\nExample:\n${t.example.split("\n").map((l) => "  " + l).join("\n")}\n`;
  if (t.availability !== "MSX1 and MSX2") s += `\nAvailable: ${t.availability}\n`;
  if (t.see.length) s += `\nSee also: ${t.see.join(", ")}\n`;
  return s;
}

class HelpProvider implements vscode.TextDocumentContentProvider {
  provideTextDocumentContent(uri: vscode.Uri): string {
    const t = helpTopics.find((x) => x.names[0] === decodeURIComponent(uri.path.replace(/^\//, "").replace(/\.txt$/, "")));
    return t ? topicText(t) : "No help for this topic.";
  }
}

async function showTopic(t: HelpTopic): Promise<void> {
  const uri = vscode.Uri.parse(`samprbasic-help:/${encodeURIComponent(t.names[0])}.txt`);
  const doc = await vscode.workspace.openTextDocument(uri);
  await vscode.window.showTextDocument(doc, { viewColumn: vscode.ViewColumn.Beside, preview: true, preserveFocus: false });
}

async function cmdHelpWord(): Promise<void> {
  const ed = vscode.window.activeTextEditor;
  if (!ed) return;
  const range = ed.document.getWordRangeAtPosition(ed.selection.active, /[A-Za-z_][A-Za-z0-9_]*\$?|__ASM|__ENDASM/);
  const word = range ? ed.document.getText(range) : "";
  const t = word ? findTopic(word) : undefined;
  if (t) await showTopic(t);
  else if (word) vscode.window.setStatusBarMessage(`No help for ${word}`, 3000);
  else await cmdHelpIndex();
}

async function cmdHelpIndex(): Promise<void> {
  const items = helpTopics.map((t) => ({ label: t.names[0], description: t.category, detail: t.syntax[0], topic: t }));
  const pick = await vscode.window.showQuickPick(items, { placeHolder: "Help topic (statement, function, option, guide...)", matchOnDescription: true, matchOnDetail: true });
  if (pick) await showTopic(pick.topic);
}

// ---------------------------------------------------------------- segments (F8)
async function cmdSegment(): Promise<void> {
  const ed = vscode.window.activeTextEditor;
  if (!ed || ed.document.languageId !== "samprbasic") return;
  const doc = ed.document;
  if (doc.isUntitled) { vscode.window.showWarningMessage("Save the file first."); return; }
  const base = baseName(doc.fileName);
  const m = SEGMENT_RE.exec(base);
  if (!m) { vscode.window.showWarningMessage("Not a segment file (5 chars+3 digits)."); return; }
  const answer = await vscode.window.showInputBox({ prompt: "Segment number (0-255, leading zeros optional)", validateInput: (v) => (/^\d{1,3}$/.test(v) && +v < 256 ? undefined : "Segment number 0-255") });
  if (answer === undefined) return;
  const n = String(parseInt(answer, 10)).padStart(3, "0");
  const dir = path.dirname(doc.fileName);
  const spb = findFile(dir, `${m[1]}${n}${path.extname(doc.fileName)}`);
  const bin = findFile(dir, `${m[1]}${n}.BIN`);
  if (!spb && bin) { vscode.window.showWarningMessage("BIN segments cannot be opened."); return; }
  if (!spb) { vscode.window.showWarningMessage("Segment file does not exist."); return; }
  if (doc.isDirty) await doc.save();
  await vscode.window.showTextDocument(vscode.Uri.file(spb));
}

// ---------------------------------------------------------------- new project
async function cmdNewProject(): Promise<void> {
  const samples = path.join(extPath, "samples");
  const names = fs.readdirSync(samples).filter((f) => f.toUpperCase().endsWith(".SPB"));
  const pick = await vscode.window.showQuickPick(names, { placeHolder: "Sample program to copy into the workspace" });
  if (!pick) return;
  const folder = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
  if (!folder) { vscode.window.showWarningMessage("Open a folder first."); return; }
  const dest = path.join(folder, pick);
  fs.copyFileSync(path.join(samples, pick), dest);
  await vscode.window.showTextDocument(vscode.Uri.file(dest));
}

// ---------------------------------------------------------------- activation
export function activate(ctx: vscode.ExtensionContext): void {
  extPath = ctx.extensionPath;
  diagnostics = vscode.languages.createDiagnosticCollection("samprbasic");
  output = vscode.window.createOutputChannel("SamPr Basic");
  statusItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 10);
  statusItem.text = "SamPr Basic";
  statusItem.command = "samprbasic.about";
  loadHelp();

  ctx.subscriptions.push(
    diagnostics, output, statusItem,
    vscode.commands.registerCommand("samprbasic.run", cmdRun),
    vscode.commands.registerCommand("samprbasic.build", cmdBuild),
    vscode.commands.registerCommand("samprbasic.helpWord", cmdHelpWord),
    vscode.commands.registerCommand("samprbasic.helpIndex", cmdHelpIndex),
    vscode.commands.registerCommand("samprbasic.segment", cmdSegment),
    vscode.commands.registerCommand("samprbasic.newProject", cmdNewProject),
    vscode.commands.registerCommand("samprbasic.about", () => vscode.window.showInformationMessage(ABOUT, { modal: true }, "OK")),
    vscode.workspace.registerTextDocumentContentProvider("samprbasic-help", new HelpProvider()),
    vscode.workspace.onDidChangeTextDocument((e) => scheduleLive(e.document)),
    vscode.workspace.onDidOpenTextDocument((d) => scheduleLive(d)),
    vscode.window.onDidChangeActiveTextEditor((e) => { if (e) { statusItem[e.document.languageId === "samprbasic" ? "show" : "hide"](); scheduleLive(e.document); } }),
    vscode.languages.registerHoverProvider("samprbasic", {
      provideHover(doc, pos) {
        const r = doc.getWordRangeAtPosition(pos, /[A-Za-z_][A-Za-z0-9_]*\$?/);
        if (!r) return undefined;
        const t = findTopic(doc.getText(r));
        if (!t) return undefined;
        const md = new vscode.MarkdownString();
        md.appendCodeblock(t.syntax.join("\n"), "samprbasic");
        md.appendText(t.description);
        if (t.example) md.appendCodeblock(t.example, "samprbasic");
        return new vscode.Hover(md, r);
      },
    }),
    vscode.languages.registerDocumentSymbolProvider("samprbasic", {
      provideDocumentSymbols(doc) {
        const out: vscode.DocumentSymbol[] = [];
        for (let i = 0; i < doc.lineCount; i++) {
          const text = doc.lineAt(i).text;
          const m = /^\s*(SUB|FUNCTION)\s+([A-Za-z_][A-Za-z0-9_]*\$?)/i.exec(text);
          const l = /^\s*([A-Za-z_][A-Za-z0-9_]*):\s*$/.exec(text);
          const rng = doc.lineAt(i).range;
          if (m) out.push(new vscode.DocumentSymbol(m[2], m[1].toUpperCase(), m[1].toUpperCase() === "SUB" ? vscode.SymbolKind.Method : vscode.SymbolKind.Function, rng, rng));
          else if (l) out.push(new vscode.DocumentSymbol(l[1], "label", vscode.SymbolKind.Key, rng, rng));
        }
        return out;
      },
    }),
  );
  if (vscode.window.activeTextEditor?.document.languageId === "samprbasic") { statusItem.show(); scheduleLive(vscode.window.activeTextEditor.document); }
}

export function deactivate(): void { /* nothing */ }
