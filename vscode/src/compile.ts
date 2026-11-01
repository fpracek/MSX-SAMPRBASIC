// Runs the real SamPr Basic compiler (QBC.COM and, as needed, QBCR.COM / QBCB.COM) inside the Z80 host.
import * as fs from "fs";
import * as path from "path";
import { DosMachine, VFS } from "./dos";

export const ERROR_TEXT: Record<number, string> = {
  1: "Syntax error", 2: "Undefined line number or label", 3: "Not supported yet", 4: "Illegal character", 5: "Block not closed",
  6: "ELSE / END IF / NEXT / WEND without a block", 7: "Duplicate name", 8: "Too many variables, labels or blocks", 9: "Program too big",
  10: "Source too big", 11: "File read error", 12: "File write error", 13: "Not allowed with the chosen OPTION", 14: "Type mismatch or undeclared array",
  15: "Program data too big", 16: "Runtime file (RT.BIN) not found", 17: "Assembler: syntax or operand error", 18: "Assembler: value or jump out of range",
  19: "Assembler: duplicate symbol or missing __ENDASM", 20: "Assembler overlay (QASM.OVL) not found",
};

export interface Diagnostic { file: string; line: number; code: number; message: string; }
export interface CompileResult {
  ok: boolean;
  kind: "dos" | "bin" | "rom" | "unknown";
  /** Name of the file produced (NAME.COM / NAME.BIN / NAME.ROM), as written in the project folder. */
  output?: string;
  diagnostics: Diagnostic[];
  console: string;
  written: string[];
  steps?: number;
}

export interface CompileOptions {
  /** Unsaved editor contents (upper-case MSX name -> bytes): they win over the files on disk. */
  overrides?: Map<string, Uint8Array>;
  /** Do not write anything to disk (live diagnostics). */
  dryRun?: boolean;
}

/** Virtual disk: the project folder (read/write) in front of the folder with the compiler files (read only). */
export class DirVfs implements VFS {
  written = new Set<string>();
  private memory = new Map<string, Uint8Array>();
  private removed = new Set<string>();
  constructor(private projectDir: string, private toolsDir: string, private opts: CompileOptions = {}) {}

  private find(dir: string, name: string): string | undefined {
    const up = name.toUpperCase();
    try {
      for (const f of fs.readdirSync(dir)) if (f.toUpperCase() === up) return path.join(dir, f);
    } catch { /* missing folder */ }
    return undefined;
  }

  read(name: string): Uint8Array | undefined {
    const up = name.toUpperCase();
    const mem = this.memory.get(up);
    if (mem) return mem;
    if (this.removed.has(up)) return undefined;
    const ov = this.opts.overrides?.get(up);
    if (ov) return ov;
    const p = this.find(this.projectDir, name) ?? this.find(this.toolsDir, name);
    if (!p) return undefined;
    try { return new Uint8Array(fs.readFileSync(p)); } catch { return undefined; }
  }

  write(name: string, data: Uint8Array): void {
    const up = name.toUpperCase();
    this.removed.delete(up);
    if (this.opts.dryRun) { this.memory.set(up, data); this.written.add(up); return; }
    const p = this.find(this.projectDir, name) ?? path.join(this.projectDir, up);
    fs.writeFileSync(p, data);
    this.written.add(path.basename(p));
  }

  delete(name: string): void {
    const up = name.toUpperCase();
    this.memory.delete(up);
    if (this.opts.dryRun) { this.removed.add(up); return; }
    const p = this.find(this.projectDir, name);
    if (p) { try { fs.unlinkSync(p); } catch { /* ignore */ } }
  }
}

/** Compile `file` (a name like "PROG.SPB" in projectDir). */
export function compile(projectDir: string, toolsDir: string, file: string, opts: CompileOptions = {}): CompileResult {
  const vfs = new DirVfs(projectDir, toolsDir, opts);
  const result: CompileResult = { ok: false, kind: "unknown", diagnostics: [], console: "", written: [] };
  const qbc = vfs.read("QBC.COM");
  if (!qbc) {
    result.diagnostics.push({ file, line: 1, code: 16, message: "QBC.COM not found in the extension tools folder" });
    return result;
  }
  const host = new DosMachine(vfs);
  host.boot(qbc, file);
  for (let hops = 0; hops < 8; hops++) {
    const stop = host.run();
    if (stop.kind === "timeout") { result.diagnostics.push({ file, line: 1, code: 0, message: "Compiler did not finish (timeout)" }); break; }
    if (stop.kind !== "chain") break;
    const { name, tail } = stop.req;
    const up = name.toUpperCase();
    if (up === "QBCR.COM" || up === "QBCB.COM") {
      const tool = vfs.read(up);
      if (!tool) { result.diagnostics.push({ file, line: 1, code: 16, message: `${up} not found in the extension tools folder` }); break; }
      host.loadProgram(tool);
      continue;
    }
    if (up === "SAMPRBAS.COM") {
      // The compiler reloads the editor: the command tail says how it went.
      const m = /^(\S+)\s+E(\d+)\s+(\d+)$/.exec(tail);
      if (m) {
        const code = parseInt(m[3], 10);
        result.diagnostics.push({ file: m[1], line: parseInt(m[2], 10), code, message: ERROR_TEXT[code] ?? `Error ${code}` });
      } else {
        result.ok = true;
        const w = /(ROM|BIN) written: (\S+)/.exec(host.console);
        if (w) { result.kind = w[1] === "ROM" ? "rom" : "bin"; result.output = w[2]; }
      }
      break;
    }
    // Any other name is the compiled DOS program (NAME.COM): the compilation succeeded.
    result.ok = true;
    result.kind = "dos";
    result.output = name;
    break;
  }
  result.console = host.console;
  result.written = [...vfs.written];
  return result;
}
