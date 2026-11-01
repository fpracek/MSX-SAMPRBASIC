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
import { LaunchConfig } from "./openmsx";
import { AgentEvent, MsxAgent } from "./agent";

export interface DebugEnv { toolsDir: string; extensionPath: string; cfg: () => LaunchConfig; }

interface Abi { base: number; rtDbg: number; rtEnd: number; dbgt: number; }
interface LocalVar { name: string; type: number; off: number; }
interface Routine { start: number; end: number; vars: LocalVar[]; }
interface GlobalVar { name: string; suffix: string; addr: number; count: number; }

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
  private kind: "dos" | "bin" = "dos";

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
      const built = this.buildDebugCopy(this.programPath);
      if (!built.result.ok) {
        for (const d of built.result.diagnostics) this.out(`${d.file}:${d.line}: error ${d.code}: ${d.message}`, "stderr");
        throw new Error("The program does not compile.");
      }
      const kind = built.result.kind;
      if (kind !== "dos" && kind !== "bin") throw new Error("Only DOS programs and BIN programs can be debugged (not ROM cartridges).");
      this.kind = kind;
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
  private buildDebugCopy(program: string): { dir: string; result: CompileResult } {
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
    if (!/^\s*OPTION\s+DEBUG\b/im.test(text)) {
      const at = debugInsertPoint(this.origLines);
      const lines = this.origLines.slice();
      lines.splice(at, 0, "OPTION DEBUG");
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
    else if (e.name === "stopped") {
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
  }

  // ---------------------------------------------------------------- execution control
  private async resume(): Promise<void> {
    this.running = true;
    await this.agent!.send("debug cont");
  }

  protected async continueRequest(response: DebugProtocol.ContinueResponse): Promise<void> {
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

  protected async nextRequest(response: DebugProtocol.NextResponse): Promise<void> { this.sendResponse(response); await this.stepTo(`[reg HL] != ${this.curHook}`, "step"); }
  protected async stepInRequest(response: DebugProtocol.StepInResponse): Promise<void> { this.sendResponse(response); await this.stepTo(`[reg HL] != ${this.curHook}`, "step"); }

  protected async stepOutRequest(response: DebugProtocol.StepOutResponse): Promise<void> {
    this.sendResponse(response);
    await this.loadTables();
    const r = this.routineAt(this.curHook);
    if (r) await this.stepTo(`([reg HL] < ${r.start} || [reg HL] > ${r.end})`, "step");
    else { await this.clearStepBreakpoints(); await this.resume(); }
  }

  protected async pauseRequest(response: DebugProtocol.PauseResponse): Promise<void> {
    this.sendResponse(response);
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
    if (this.tableLoaded || !this.agent || !this.abi || this.running || !this.curHook) return;
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
    const line = this.origLines[this.origLineOf(r.start - 1) - 1] ?? "";
    const m = /^\s*(SUB|FUNCTION)\s+([A-Za-z_][A-Za-z0-9_]*\$?)/i.exec(line);
    return m ? `${m[1].toUpperCase()} ${m[2]}` : "routine";
  }

  protected async stackTraceRequest(response: DebugProtocol.StackTraceResponse): Promise<void> {
    if (this.running || !this.curHook) { response.body = { stackFrames: [], totalFrames: 0 }; this.sendResponse(response); return; }
    await this.loadTables();
    const r = this.routineAt(this.curHook);
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
