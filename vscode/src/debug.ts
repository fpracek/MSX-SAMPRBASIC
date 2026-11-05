// Source-level debugger for SamPr Basic on openMSX (Debug Adapter Protocol).
// The program is compiled with OPTION DEBUG (a hook before every statement: HL = line, IX = frame of the current routine) against the plain
// runtime, so the hook costs almost nothing; openMSX conditional breakpoints on the hook give breakpoints and stepping, and the variables are
// read from the same tables the on-screen debugger of the MSX uses.
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import {
  DebugSession, InitializedEvent, OutputEvent, StoppedEvent, TerminatedEvent, Thread, StackFrame, Scope, Source, Handles, Variable,
} from "@vscode/debugadapter";
import { DebugProtocol } from "@vscode/debugprotocol";
import { compile, CompileResult } from "./compile";
import { LaunchConfig, romTypeFor } from "./openmsx";
import { AgentEvent, MsxAgent } from "./agent";

export interface DebugEnv { toolsDir: string; extensionPath: string; cfg: () => LaunchConfig; }

interface Abi { base: number; rtDbg: number; rtEnd: number; dbgt: number; }
interface LocalVar { name: string; type: number; off: number; }
interface Routine { start: number; end: number; vars: LocalVar[]; }
interface GlobalVar { name: string; suffix: string; addr: number; count: number; }
/** ROM cartridge map (NAME.MAP written by the compiler under OPTION MAP). */
interface MapStmt { file: number; seg: number; addr: number; line: number; }
interface MapFunc { file: number; seg: number; name: string; line1: number; routine: Routine; }
interface RomMap { target: number; stmts: MapStmt[]; funcs: MapFunc[]; globals: GlobalVar[]; }

/** Parse NAME.MAP. Addresses of routines are encoded as seg * 65536 + address, so that one number tells where the code is. */
export function parseMap(d: Buffer): RomMap {
  if (d.length < 6 || d.toString("latin1", 0, 4) !== "SPBM") throw new Error("Invalid map file");
  const m: RomMap = { target: d[5], stmts: [], funcs: [], globals: [] };
  const rec = (b: Buffer, o: number) => {
    const z = b.subarray(o, o + 11).indexOf(0);
    return { name: b.subarray(o, o + (z < 0 ? 11 : z)).toString("latin1"), suffix: b[o + 11] };
  };
  let i = 6;
  while (i < d.length) {
    const t = String.fromCharCode(d[i]);
    if (t === "S") {
      m.stmts.push({ file: d[i + 1], seg: d[i + 2], addr: d.readUInt16LE(i + 3), line: d.readUInt16LE(i + 5) });
      i += 7;
    } else if (t === "F") {
      const file = d[i + 1], seg = d[i + 2];
      const z = d.subarray(i + 3, i + 15).indexOf(0);
      const name = d.subarray(i + 3, i + (z < 0 ? 15 : 3 + z)).toString("latin1");
      const entry = d.readUInt16LE(i + 15), line1 = d.readUInt16LE(i + 17), end = d.readUInt16LE(i + 21), n = d[i + 23];
      const vars: LocalVar[] = [];
      for (let k = 0; k < n; k++) {
        const o = i + 24 + k * 16;
        const r = rec(d, o);
        vars.push({ name: r.name + (r.suffix === 0x24 ? "$" : ""), type: d[o + 12], off: d.readUInt16LE(o + 13) });
      }
      m.funcs.push({ file, seg, name, line1, routine: { start: seg * 65536 + entry, end: seg * 65536 + end, vars } });
      i += 24 + n * 16;
    } else if (t === "G") {
      const n = d[i + 1];
      for (let k = 0; k < n; k++) {
        const o = i + 2 + k * 16;
        const r = rec(d, o);
        const count = d.readUInt16LE(o + 14);
        if (r.name && count !== 0xffff) m.globals.push({ name: r.name, suffix: String.fromCharCode(r.suffix), addr: d.readUInt16LE(o + 12), count });
      }
      i += 2 + n * 16;
    } else break; // 'E'
  }
  return m;
}

const THREAD = 1;

function s16(n: number): number { return n >= 0x8000 ? n - 0x10000 : n; }
function s8(n: number): number { return n >= 0x80 ? n - 0x100 : n; }

/** Where to insert "OPTION DEBUG": after the leading blank, comment and OPTION lines. Returns the number of original lines before it. */
export function debugInsertPoint(lines: string[]): number {
  let i = 0;
  while (i < lines.length && /^\s*($|REM\b|'|OPTION\b)/i.test(lines[i])) i++;
  return i;
}

export class SamprDebugSession extends DebugSession {
  private env: DebugEnv;
  private agent: MsxAgent | undefined;
  private abi: Abi | undefined;
  private programPath = "";
  private origLines: string[] = [];
  private inserted = -1; // number of original lines before the inserted OPTION DEBUG line (-1: none inserted)
  private sig: number[] = [];
  private bpIds = new Map<string, string[]>();
  private entryBp: string | undefined;
  private tempBp: string | undefined;
  private endBp: string | undefined;
  private running = false;
  private finished = false;
  private curHook = 0;
  private curIx = 0;
  private globals: GlobalVar[] = [];
  private routines: Routine[] = [];
  private tableLoaded = false;
  private idCase = new Map<string, string>();
  private shown(name: string): string {
    const dollar = name.endsWith("$");
    const base = dollar ? name.slice(0, -1) : name;
    return (this.idCase.get(base.toUpperCase()) ?? base) + (dollar ? "$" : "");
  }
  private varHandles = new Handles<{ kind: "locals" | "globals" | "array"; index?: number }>();
  private kind: "dos" | "bin" | "rom" = "dos";
  // ROM cartridges (address breakpoints, no hooks in the program)
  private romMap: RomMap | undefined;
  private romBytes: Buffer = Buffer.alloc(0);
  private romFiles: string[] = [];
  private fileText = new Map<number, string[]>();
  private curStmt: MapStmt | undefined;
  private curSp = 0;
  private romBpIds: string[] = [];

  constructor(env: DebugEnv) {
    super();
    this.env = env;
    this.setDebuggerLinesStartAt1(true);
    this.setDebuggerColumnsStartAt1(true);
  }

  // ---------------------------------------------------------------- line mapping
  private hookLineOf(orig: number): number { return this.inserted >= 0 && orig > this.inserted ? orig + 1 : orig; }
  private origLineOf(hook: number): number {
    if (this.inserted < 0) return hook;
    if (hook === this.inserted + 1) return this.inserted === 0 ? 1 : this.inserted; // the inserted line itself
    return hook > this.inserted + 1 ? hook - 1 : hook;
  }

  // ---------------------------------------------------------------- DAP: setup
  protected initializeRequest(response: DebugProtocol.InitializeResponse): void {
    response.body = {
      supportsConfigurationDoneRequest: true,
      supportsEvaluateForHovers: true,
      supportsTerminateRequest: true,
      supportsSingleThreadExecutionRequests: false,
    };
    this.sendResponse(response);
  }

  private out(text: string, cat: "console" | "stderr" = "console"): void { this.sendEvent(new OutputEvent(text + "\n", cat)); }

  protected async launchRequest(response: DebugProtocol.LaunchResponse, args: DebugProtocol.LaunchRequestArguments & { program?: string; stopOnEntry?: boolean }): Promise<void> {
    try {
      this.programPath = args.program ?? "";
      if (!this.programPath || !fs.existsSync(this.programPath)) throw new Error(`Program not found: ${this.programPath}`);
      const stopOnEntry = args.stopOnEntry !== false;
      const isRom = /^\s*OPTION\s+TARGET\s+ROM/im.test(fs.readFileSync(this.programPath, "latin1"));
      const built = this.buildDebugCopy(this.programPath, isRom);
      if (!built.result.ok) {
        for (const d of built.result.diagnostics) this.out(`${d.file}:${d.line}: error ${d.code}: ${d.message}`, "stderr");
        throw new Error("The program does not compile.");
      }
      const kind = built.result.kind;
      if (kind !== "dos" && kind !== "bin" && kind !== "rom") throw new Error("This kind of program cannot be debugged.");
      this.kind = kind;
      if (kind === "rom") { await this.launchRom(response, built.dir, built.result.output!, stopOnEntry); return; }
      const abi = JSON.parse(fs.readFileSync(path.join(this.env.extensionPath, "data", "abi.json"), "utf8"))[kind] as Abi;
      this.abi = abi;
      const outFile = path.join(built.dir, built.result.output!);
      const image = fs.readFileSync(outFile);
      // signature of the compiled image: it tells the program from MSX-DOS' own code running at the same addresses
      const off = kind === "bin" ? 7 : 0;
      this.sig = [image[off], image[off + 1], image[off + 2]];
      const agent = new MsxAgent();
      this.agent = agent;
      agent.onEvent = (e) => this.onAgentEvent(e);
      agent.onExit = () => { if (!this.finished) { this.finished = true; this.sendEvent(new TerminatedEvent()); } };
      this.startMsx(agent, built.dir, outFile, kind);
      await this.waitReady();
      this.out(`Debugging ${path.basename(this.programPath)} (${kind.toUpperCase()}) in openMSX`);
      if (stopOnEntry) {
        this.entryBp = (await agent.send(`debug set_bp ${abi.rtDbg} {${this.sigCond()}} {spb_hit}`)).trim();
      }
      this.endBp = (await agent.send(`debug set_bp ${abi.rtEnd} {${this.sigCond()}} {spb_end}`)).trim();
      this.sendResponse(response);
      this.sendEvent(new InitializedEvent());
    } catch (e) {
      this.out(String((e as Error).message ?? e), "stderr");
      response.success = false;
      response.message = String((e as Error).message ?? e);
      this.sendResponse(response);
      this.sendEvent(new TerminatedEvent());
    }
  }

  // ---------------------------------------------------------------- ROM cartridges
  private fileLinesOf(idx: number): string[] {
    let l = this.fileText.get(idx);
    if (!l) {
      try { l = fs.readFileSync(this.romFiles[idx], "latin1").split(/\r?\n/); } catch { l = []; }
      this.fileText.set(idx, l);
    }
    return l;
  }

  /** Source files of a multi-file ROM: NAME000.SPB, NAME001.SPB... (or the single file). */
  private romSourceFiles(program: string, count: number): string[] {
    const m = /^(.*?)(\d{3})(\.[^.]+)$/.exec(path.basename(program));
    const dir = path.dirname(program);
    const out = [program];
    if (m) for (let i = 1; i < count; i++) out.push(path.join(dir, m[1] + String(i).padStart(3, "0") + m[3]));
    return out;
  }

  /** Byte offset in the ROM file of a code address of segment `seg`. */
  private romOffset(seg: number, addr: number): number {
    if (seg === 0) return addr - 0x4000;
    const sz = this.romMap!.target === 4 ? 16384 : 8192;
    return 16384 + (seg - 1) * sz + (addr - 0x8000);
  }

  /** Condition that tells segment `seg` from the others mapped in the same window: the first bytes at the address (code at 4000h-7FFFh is always there). */
  private bankCond(seg: number, addr: number): string {
    if (addr < 0x8000) return "";
    const mine = (n: number) => this.romBytes.subarray(this.romOffset(seg, addr), this.romOffset(seg, addr) + n);
    const others = new Set<number>(this.romMap!.stmts.filter((x) => x.seg !== seg && x.seg > 0).map((x) => x.seg));
    let n = 3;
    for (; n < 12; n++) {
      let same = false;
      for (const o of others) {
        const off = this.romOffset(o, addr);
        if (off + n <= this.romBytes.length && this.romBytes.subarray(off, off + n).equals(mine(n))) { same = true; break; }
      }
      if (!same) break;
    }
    return [...mine(n)].map((b, i) => `[peek ${addr + i}] == ${b}`).join(" && ");
  }

  private async launchRom(response: DebugProtocol.LaunchResponse, dir: string, output: string, stopOnEntry: boolean): Promise<void> {
    const mapPath = path.join(dir, output.replace(/\.ROM$/i, ".MAP"));
    if (!fs.existsSync(mapPath)) throw new Error("The compiler did not write the map file.");
    const map = parseMap(fs.readFileSync(mapPath));
    this.romMap = map;
    this.romBytes = fs.readFileSync(path.join(dir, output));
    this.romFiles = this.romSourceFiles(this.programPath, Math.max(...map.stmts.map((x) => x.file), 0) + 1);
    this.globals = map.globals;
    this.routines = map.funcs.map((f) => f.routine);
    this.tableLoaded = true;
    this.abi = JSON.parse(fs.readFileSync(path.join(this.env.extensionPath, "data", "abi.json"), "utf8")).rom as Abi;
    const agent = new MsxAgent();
    this.agent = agent;
    agent.onEvent = (e) => this.onAgentEvent(e);
    agent.onExit = () => { if (!this.finished) { this.finished = true; this.sendEvent(new TerminatedEvent()); } };
    const type = romTypeFor(fs.readFileSync(this.programPath, "latin1"));
    agent.start(this.env.cfg(), ["-cart", path.join(dir, output), "-romtype", type], "set pause on\n");
    await this.waitReady();
    this.out(`Debugging ${path.basename(this.programPath)} (ROM, ${this.romFiles.length} file${this.romFiles.length > 1 ? "s" : ""}) in openMSX`);
    // one breakpoint on every statement: the Tcl variables ::spb_mode / ::spb_sp decide whether it stops (0: never)
    const items: string[] = [];
    for (const st of map.stmts) {
      const c = this.bankCond(st.seg, st.addr);
      items.push(`${st.addr} {$::spb_mode != 0 && ($::spb_mode == 1 || ($::spb_mode == 2 && [reg SP] >= $::spb_sp) || ($::spb_mode == 3 && [reg SP] > $::spb_sp))${c ? " && " + c : ""}}`);
    }
    const ids = (await agent.send(`set ids {}; foreach {a c} {${items.join(" ")}} { lappend ids [debug set_bp $a $c {spb_rhit}] }; set ids`, 120000)).trim();
    this.romBpIds = ids ? ids.split(/\s+/) : [];
    this.endBp = (await agent.send(`debug set_bp ${this.abi.rtEnd} {} {spb_end}`)).trim();
    await agent.send(`set ::spb_mode ${stopOnEntry ? 1 : 0}`);
    this.sendResponse(response);
    this.sendEvent(new InitializedEvent());
  }

  /** The statement whose code starts at `pc` (several segments may share the address: the bytes tell which one is mapped). */
  private async stmtAt(pc: number): Promise<MapStmt | undefined> {
    const c = this.romMap!.stmts.filter((x) => x.addr === pc);
    if (c.length <= 1) return c[0];
    // statements without code of their own (DO, ELSE...) share the address of the next one: that one is the line to show
    const segs = [...new Set(c.map((x) => x.seg))];
    if (segs.length === 1) return c[c.length - 1];
    const now = await this.agent!.readMem(pc, 12);
    let best = c[0], bestN = -1;
    for (const st of c) {
      const off = this.romOffset(st.seg, st.addr);
      let n = 0;
      while (n < 12 && this.romBytes[off + n] === now[n]) n++;
      if (n > bestN) { best = st; bestN = n; }
    }
    return best;
  }

  private romLine(file: number, line: number): number { return file === 0 ? this.origLineOf(line) : line; }

  private async romBreakpoints(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments): Promise<void> {
    const key = path.resolve(args.source.path ?? "").toLowerCase();
    const file = this.romFiles.findIndex((f) => path.resolve(f).toLowerCase() === key);
    const bps: DebugProtocol.Breakpoint[] = [];
    const items: string[] = [];
    for (const sb of args.breakpoints ?? []) {
      if (file < 0) { bps.push({ verified: false, line: sb.line }); continue; }
      const want = file === 0 ? this.hookLineOf(sb.line) : sb.line;
      // the first statement on the line; on a line without code, the next line that has some
      const cands = this.romMap!.stmts.filter((x) => x.file === file && x.line >= want);
      if (!cands.length) { bps.push({ verified: false, line: sb.line }); continue; }
      const best = Math.min(...cands.map((x) => x.line));
      const st = cands.find((x) => x.line === best)!;
      const c = this.bankCond(st.seg, st.addr);
      items.push(`${st.addr} {${c || "1"}}`);
      bps.push({ verified: true, line: this.romLine(file, best) });
    }
    const old = this.bpIds.get(key) ?? [];
    if (old.length) await this.agent!.send(`foreach id {${old.join(" ")}} { catch {debug remove_bp $id} }`);
    const ids = items.length ? (await this.agent!.send(`set ids {}; foreach {a c} {${items.join(" ")}} { lappend ids [debug set_bp $a $c {spb_rhit}] }; set ids`)).trim() : "";
    this.bpIds.set(key, ids ? ids.split(/\s+/) : []);
    response.body = { breakpoints: bps };
    this.sendResponse(response);
  }

  /** Continue (mode 0), step into (1), over (2) or out (3): the statement breakpoints stop according to ::spb_mode and the stack pointer. */
  private async romResume(mode: number): Promise<void> {
    this.running = true;
    await this.agent!.send(`set ::spb_mode ${mode}; set ::spb_sp ${this.curSp}; set ::spb_stopped 0; debug cont`);
  }

  private sigCond(): string {
    const b = this.abi!.base + (this.kind === "bin" ? 0 : 0);
    return `[peek ${b}] == ${this.sig[0]} && [peek ${b + 1}] == ${this.sig[1]} && [peek ${b + 2}] == ${this.sig[2]}`;
  }

  private waitReady(): Promise<void> {
    return new Promise((resolve, reject) => {
      const t0 = Date.now();
      const tick = () => {
        if (this.readyFlag) { resolve(); return; }
        if (this.agent?.exited) { reject(new Error("openMSX exited at start-up. Check 'samprbasic.openmsx.path'.")); return; }
        if (Date.now() - t0 > 40000) { reject(new Error("openMSX did not start.")); return; }
        setTimeout(tick, 50);
      };
      tick();
    });
  }
  private readyFlag = false;

  /** Copy of the project with OPTION DEBUG and a plain runtime in place of the debugging one, compiled in a temporary folder. */
  private buildDebugCopy(program: string, rom = false): { dir: string; result: CompileResult } {
    const srcDir = path.dirname(program);
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "spb-debug-"));
    for (const f of fs.readdirSync(srcDir)) {
      const p = path.join(srcDir, f);
      try { if (fs.statSync(p).isFile() && fs.statSync(p).size < 4_000_000) fs.copyFileSync(p, path.join(dir, f)); } catch { /* skip */ }
    }
    const text = fs.readFileSync(program, "latin1");
    this.origLines = text.split(/\r?\n/);
    this.idCase.clear();
    for (const m of text.matchAll(/[A-Za-z_][A-Za-z0-9_]*/g)) {
      const k = m[0].toUpperCase().slice(0, 11);
      if (!this.idCase.has(k)) this.idCase.set(k, m[0].slice(0, 11));
    }
    let modified = text;
    this.inserted = -1;
    if (!(rom ? /^\s*OPTION\s+MAP\b/im : /^\s*OPTION\s+DEBUG\b/im).test(text)) {
      const at = debugInsertPoint(this.origLines);
      const lines = this.origLines.slice();
      lines.splice(at, 0, rom ? "OPTION MAP" : "OPTION DEBUG");
      modified = lines.join("\r\n");
      this.inserted = at;
    }
    const file = path.basename(program).toUpperCase();
    fs.writeFileSync(path.join(dir, path.basename(program)), Buffer.from(modified, "latin1"));
    const rt = fs.readFileSync(path.join(this.env.toolsDir, "RT.BIN"));
    const result = compile(dir, this.env.toolsDir, file, { overrides: new Map([["RTD.BIN", new Uint8Array(rt)]]) });
    return { dir, result };
  }

  private startMsx(agent: MsxAgent, dir: string, outFile: string, kind: "dos" | "bin"): void {
    const cfg = this.env.cfg();
    const fsFlag = cfg.fullSpeed ? "catch {set fullspeedwhenloading on}\n" : "";
    const typeAt = (at: number, lines: string[], first: boolean) => lines.map((ln, i) => `after time ${at + 2 * i} {${first && i === 0 ? "set throttle on; " : ""}type "${ln}\\r"}\n`).join("");
    if (kind === "bin") {
      const bdir = fs.mkdtempSync(path.join(os.tmpdir(), "spb-debug-disk-"));
      const name = path.basename(outFile).toUpperCase();
      fs.copyFileSync(outFile, path.join(bdir, name));
      agent.start(cfg, ["-diska", bdir], "set throttle off\n" + fsFlag + typeAt(24, ["CLEAR 200,&H83FF", `BLOAD\\"${name}\\",R`], true));
    } else {
      if (!cfg.dosFiles) throw new Error("Set 'samprbasic.dosFiles' to the folder that holds MSXDOS.SYS and COMMAND.COM.");
      const names = fs.readdirSync(cfg.dosFiles);
      for (const f of ["MSXDOS.SYS", "COMMAND.COM", "MSXDOS2.SYS", "COMMAND2.COM"]) {
        const src = names.find((x) => x.toUpperCase() === f);
        if (src) fs.copyFileSync(path.join(cfg.dosFiles, src), path.join(dir, f));
      }
      const prog = path.basename(outFile, path.extname(outFile)).toUpperCase();
      agent.start(cfg, ["-diska", dir], "set throttle off\n" + fsFlag + typeAt(22, cfg.askDate ? ["1-1-86", prog] : [prog], true));
    }
  }

  // ---------------------------------------------------------------- agent events
  private onAgentEvent(e: AgentEvent): void {
    if (e.name === "ready") this.readyFlag = true;
    else if (e.name === "stopped" && this.kind === "rom") {
      this.curIx = parseInt(e.args[1], 10) & 0xffff;
      this.curSp = parseInt(e.args[3], 10) & 0xffff;
      this.running = false;
      void this.stmtAt(parseInt(e.args[2], 10) & 0xffff).then((st) => {
        this.curStmt = st;
        this.curHook = st ? st.seg * 65536 + st.addr : 0;
        const reason = this.pendingReason ?? "breakpoint";
        this.pendingReason = undefined;
        this.sendEvent(new StoppedEvent(reason, THREAD));
      });
    } else if (e.name === "stopped") {
      const hook = parseInt(e.args[0], 10);
      this.curHook = hook;
      this.curIx = parseInt(e.args[1], 10) & 0xffff;
      this.running = false;
      this.tableLoaded = false;
      this.tablePromise = undefined;
      void this.clearStepBreakpoints().then(() => {
        const reason = this.pendingReason ?? "breakpoint";
        this.pendingReason = undefined;
        this.sendEvent(new StoppedEvent(reason, THREAD));
      });
    } else if (e.name === "ended") {
      this.out("Program finished.");
      this.finished = true;
      this.sendEvent(new TerminatedEvent());
    }
  }
  private pendingReason: string | undefined;

  private async clearStepBreakpoints(): Promise<void> {
    if (!this.agent) return;
    for (const id of [this.entryBp, this.tempBp]) if (id) { try { await this.agent.send(`debug remove_bp ${id}`); } catch { /* ignore */ } }
    this.entryBp = undefined;
    this.tempBp = undefined;
  }

  // ---------------------------------------------------------------- breakpoints
  protected async setBreakPointsRequest(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments): Promise<void> {
    if (this.kind === "rom" && this.romMap && this.agent) { await this.romBreakpoints(response, args); return; }
    const key = args.source.path ?? "";
    const agent = this.agent;
    const bps: DebugProtocol.Breakpoint[] = [];
    if (agent && this.abi) {
      for (const id of this.bpIds.get(key) ?? []) { try { await agent.send(`debug remove_bp ${id}`); } catch { /* ignore */ } }
      const ids: string[] = [];
      for (const sb of args.breakpoints ?? []) {
        const text = this.origLines[sb.line - 1] ?? "";
        const executable = /\S/.test(text) && !/^\s*(REM\b|')/i.test(text) && !/^\s*[A-Za-z_][A-Za-z0-9_]*:\s*$/.test(text);
        if (!executable) { bps.push({ verified: false, line: sb.line }); continue; }
        const id = (await agent.send(`debug set_bp ${this.abi.rtDbg} {${this.sigCond()} && [reg HL] == ${this.hookLineOf(sb.line)}} {spb_hit}`)).trim();
        ids.push(id);
        bps.push({ verified: true, line: sb.line });
      }
      this.bpIds.set(key, ids);
    }
    response.body = { breakpoints: bps };
    this.sendResponse(response);
  }

  protected configurationDoneRequest(response: DebugProtocol.ConfigurationDoneResponse): void {
    this.running = true;
    this.sendResponse(response);
    if (this.kind === "rom") void this.agent?.send("set pause off"); // the cartridge was started paused, until the breakpoints were in place
  }

  // ---------------------------------------------------------------- execution control
  private async resume(): Promise<void> {
    this.running = true;
    await this.agent!.send("debug cont");
  }

  protected async continueRequest(response: DebugProtocol.ContinueResponse): Promise<void> {
    if (this.kind === "rom") { await this.romResume(0); response.body = { allThreadsContinued: true }; this.sendResponse(response); return; }
    await this.clearStepBreakpoints();
    await this.resume();
    response.body = { allThreadsContinued: true };
    this.sendResponse(response);
  }

  private async stepTo(cond: string, reason: string): Promise<void> {
    await this.clearStepBreakpoints();
    this.pendingReason = reason;
    this.tempBp = (await this.agent!.send(`debug set_bp ${this.abi!.rtDbg} {${this.sigCond()} && ${cond}} {spb_hit}`)).trim();
    await this.resume();
  }

  protected async nextRequest(response: DebugProtocol.NextResponse): Promise<void> {
    this.sendResponse(response);
    if (this.kind === "rom") { this.pendingReason = "step"; await this.romResume(2); return; }
    await this.stepTo(`[reg HL] != ${this.curHook}`, "step");
  }
  protected async stepInRequest(response: DebugProtocol.StepInResponse): Promise<void> {
    this.sendResponse(response);
    if (this.kind === "rom") { this.pendingReason = "step"; await this.romResume(1); return; }
    await this.stepTo(`[reg HL] != ${this.curHook}`, "step");
  }

  protected async stepOutRequest(response: DebugProtocol.StepOutResponse): Promise<void> {
    this.sendResponse(response);
    if (this.kind === "rom") {
      const r = this.routineAt(this.curHook);
      this.pendingReason = "step";
      await this.romResume(r ? 3 : 0);
      return;
    }
    await this.loadTables();
    const r = this.routineAt(this.curHook);
    if (r) await this.stepTo(`([reg HL] < ${r.start} || [reg HL] > ${r.end})`, "step");
    else { await this.clearStepBreakpoints(); await this.resume(); }
  }

  protected async pauseRequest(response: DebugProtocol.PauseResponse): Promise<void> {
    this.sendResponse(response);
    if (this.kind === "rom") { this.pendingReason = "pause"; await this.agent!.send("set ::spb_mode 1"); return; }
    await this.clearStepBreakpoints();
    this.pendingReason = "pause";
    this.tempBp = (await this.agent!.send(`debug set_bp ${this.abi!.rtDbg} {${this.sigCond()}} {spb_hit}`)).trim();
  }

  protected async terminateRequest(response: DebugProtocol.TerminateResponse): Promise<void> { this.closeMsx(); this.sendResponse(response); }
  protected async disconnectRequest(response: DebugProtocol.DisconnectResponse): Promise<void> { this.closeMsx(); this.sendResponse(response); }

  private closeMsx(): void {
    if (!this.finished && this.agent) this.agent.kill(); // a finished program keeps its openMSX window (to read the output)
    this.finished = true;
  }

  // ---------------------------------------------------------------- stack, variables
  protected threadsRequest(response: DebugProtocol.ThreadsResponse): void {
    response.body = { threads: [new Thread(THREAD, "SamPr Basic")] };
    this.sendResponse(response);
  }

  private routineAt(hook: number): Routine | undefined { return this.routines.find((r) => hook >= r.start && hook <= r.end); }

  private tablePromise: Promise<void> | undefined;
  private loadTables(): Promise<void> {
    if (this.tableLoaded) return Promise.resolve();
    if (!this.tablePromise) this.tablePromise = this.doLoadTables().finally(() => { this.tablePromise = undefined; });
    return this.tablePromise;
  }

  private async doLoadTables(): Promise<void> {
    if (this.kind === "rom" || this.tableLoaded || !this.agent || !this.abi || this.running || !this.curHook) return; // a ROM has its tables in the map
    const a = this.agent;
    const dbgt = (await a.readMem(this.abi.dbgt, 2)).readUInt16LE(0);
    this.globals = [];
    this.routines = [];
    if (dbgt) {
      const head = await a.readMem(dbgt, 1);
      const n = head[0];
      const body = await a.readMem(dbgt + 1, n * 16 + 2);
      for (let i = 0; i < n; i++) {
        const o = i * 16;
        const rawName = body.subarray(o, o + 11);
        const z = rawName.indexOf(0);
        const name = rawName.subarray(0, z < 0 ? 11 : z).toString("latin1");
        const suffix = String.fromCharCode(body[o + 11]);
        const addr = body.readUInt16LE(o + 12);
        const count = body.readUInt16LE(o + 14);
        if (name && count !== 0xffff) this.globals.push({ name, suffix, addr, count });
      }
      let ptr = body.readUInt16LE(n * 16);
      for (let guard = 0; ptr && guard < 64; guard++) {
        const h = await a.readMem(ptr, 7);
        const start = h.readUInt16LE(2), end = h.readUInt16LE(4), cnt = h[6];
        const recs = await a.readMem(ptr + 7, cnt * 16);
        const vars: LocalVar[] = [];
        for (let i = 0; i < cnt; i++) {
          const o = i * 16;
          const raw = recs.subarray(o, o + 11);
          const z = raw.indexOf(0);
          const nm = raw.subarray(0, z < 0 ? 11 : z).toString("latin1") + (recs[o + 11] === 0x24 ? "$" : "");
          vars.push({ name: nm, type: recs[o + 12], off: recs.readUInt16LE(o + 13) });
        }
        this.routines.push({ start, end, vars });
        ptr = h.readUInt16LE(0);
      }
    }
    this.tableLoaded = true;
  }

  private routineName(r: Routine | undefined): string {
    if (!r) return "main";
    if (this.kind === "rom") {
      const f = this.romMap!.funcs.find((x) => x.routine === r);
      const line = f ? this.fileLinesOf(f.file)[this.romLine(f.file, f.line1) - 1] ?? "" : "";
      const m = /^\s*(SUB|FUNCTION)\s+([A-Za-z_][A-Za-z0-9_]*\$?)/i.exec(line);
      return m ? `${m[1].toUpperCase()} ${m[2]}` : this.shown(f?.name ?? "routine");
    }
    const line = this.origLines[this.origLineOf(r.start - 1) - 1] ?? "";
    const m = /^\s*(SUB|FUNCTION)\s+([A-Za-z_][A-Za-z0-9_]*\$?)/i.exec(line);
    return m ? `${m[1].toUpperCase()} ${m[2]}` : "routine";
  }

  protected async stackTraceRequest(response: DebugProtocol.StackTraceResponse): Promise<void> {
    if (this.running || !this.curHook) { response.body = { stackFrames: [], totalFrames: 0 }; this.sendResponse(response); return; }
    await this.loadTables();
    const r = this.routineAt(this.curHook);
    if (this.kind === "rom") {
      const st = this.curStmt;
      const src = st ? this.romFiles[st.file] : this.programPath;
      const frame = new StackFrame(1, this.routineName(r), new Source(path.basename(src), src), st ? this.romLine(st.file, st.line) : 0, 1);
      response.body = { stackFrames: [frame], totalFrames: 1 };
      this.sendResponse(response);
      return;
    }
    const line = this.origLineOf(this.curHook);
    const frame = new StackFrame(1, this.routineName(r), new Source(path.basename(this.programPath), this.programPath), line, 1);
    response.body = { stackFrames: [frame], totalFrames: 1 };
    this.sendResponse(response);
  }

  protected scopesRequest(response: DebugProtocol.ScopesResponse): void {
    const scopes: Scope[] = [];
    const r = this.routineAt(this.curHook);
    if (r) scopes.push(new Scope("Locals", this.varHandles.create({ kind: "locals" }), false));
    scopes.push(new Scope("Globals", this.varHandles.create({ kind: "globals" }), false));
    (scopes[0] as DebugProtocol.Scope).presentationHint = "locals"; // VS Code opens this one by itself
    response.body = { scopes };
    this.sendResponse(response);
  }

  private async readString(addr: number): Promise<string> {
    const len = (await this.agent!.readMem(addr, 1))[0];
    const data = len ? await this.agent!.readMem(addr + 1, len) : Buffer.alloc(0);
    return JSON.stringify(data.toString("latin1"));
  }

  private async globalValue(g: GlobalVar): Promise<{ value: string; ref: number }> {
    if (g.count) {
      if (g.count & 0x8000) return { value: "(mapper array)", ref: 0 };
      return { value: `[${g.count} elements]`, ref: this.varHandles.create({ kind: "array", index: this.globals.indexOf(g) }) };
    }
    if (g.suffix === "$") return { value: await this.readString(g.addr), ref: 0 };
    return { value: String(s16((await this.agent!.readMem(g.addr, 2)).readUInt16LE(0))), ref: 0 };
  }

  private async localValue(v: LocalVar): Promise<string | undefined> {
    if (v.type === 2 || v.type >= 5) return undefined;
    const off = v.type === 1 ? s16(v.off) : s8(v.off & 0xff);
    const addr = (this.curIx + off) & 0xffff;
    if (v.type === 1) return this.readString(addr);
    const w = (await this.agent!.readMem(addr, 2)).readUInt16LE(0);
    if (v.type === 4) return this.readString(w);
    if (v.name.endsWith("$")) return this.readString(w);
    return String(s16(w));
  }

  protected async variablesRequest(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments): Promise<void> {
    await this.loadTables();
    const h = this.varHandles.get(args.variablesReference);
    const vars: Variable[] = [];
    try {
      if (h?.kind === "locals") {
        const r = this.routineAt(this.curHook);
        for (const v of r?.vars ?? []) {
          const val = await this.localValue(v);
          if (val !== undefined) vars.push(new Variable(this.shown(v.name), val));
        }
      } else if (h?.kind === "globals") {
        for (const g of this.globals) {
          const { value, ref } = await this.globalValue(g);
          vars.push(new Variable(this.shown(g.name + (g.suffix === "$" ? "$" : "")), value, ref));
        }
      } else if (h?.kind === "array" && h.index !== undefined) {
        const g = this.globals[h.index];
        const n = Math.min(g.count, 256);
        if (g.suffix === "$") {
          for (let i = 0; i < n; i++) vars.push(new Variable(`${this.shown(g.name)}$(${i})`, await this.readString(g.addr + 256 * i)));
        } else {
          const data = await this.agent!.readMem(g.addr, n * 2);
          for (let i = 0; i < n; i++) vars.push(new Variable(`${this.shown(g.name)}(${i})`, String(s16(data.readUInt16LE(i * 2)))));
        }
      }
    } catch (e) {
      this.out(`Cannot read variables: ${(e as Error).message}`, "stderr");
    }
    response.body = { variables: vars };
    this.sendResponse(response);
  }

  protected async evaluateRequest(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments): Promise<void> {
    try {
      if (this.running) throw new Error("running");
      await this.loadTables();
      const m = /^\s*([A-Za-z_][A-Za-z0-9_]*)(\$?)\s*(?:\(\s*(\d+)\s*\))?\s*$/.exec(args.expression);
      if (!m) throw new Error("not a variable");
      const name = m[1].toUpperCase().slice(0, 11), str = m[2] === "$", idx = m[3] !== undefined ? parseInt(m[3], 10) : undefined;
      const r = this.routineAt(this.curHook);
      const lv = r?.vars.find((v) => v.name.toUpperCase().replace(/\$$/, "") === name && v.name.endsWith("$") === str);
      if (lv && idx === undefined) {
        const val = await this.localValue(lv);
        if (val !== undefined) { response.body = { result: val, variablesReference: 0 }; this.sendResponse(response); return; }
      }
      const g = this.globals.find((x) => x.name.toUpperCase() === name && (x.suffix === "$") === str);
      if (!g) throw new Error("unknown variable");
      if (g.count && idx !== undefined) {
        if (idx >= g.count) throw new Error("index out of range");
        const v = str ? await this.readString(g.addr + 256 * idx) : String(s16((await this.agent!.readMem(g.addr + 2 * idx, 2)).readUInt16LE(0)));
        response.body = { result: v, variablesReference: 0 };
      } else {
        const gv = await this.globalValue(g);
        response.body = { result: gv.value, variablesReference: gv.ref };
      }
      this.sendResponse(response);
    } catch (e) {
      response.success = false;
      response.message = (e as Error).message;
      this.sendResponse(response);
    }
  }
}
