// Minimal MSX-DOS 1 host around a Z80 emulator: it runs the real QBC.COM / QBCR.COM / QBCB.COM compilers
// (the same binaries that run on the MSX) with a simulated BDOS and a virtual disk.
import { Z80, Hal } from "z80-emulator";

export interface VFS {
  /** Read a file by MSX name ("NAME.EXT", upper case). */
  read(name: string): Uint8Array | undefined;
  write(name: string, data: Uint8Array): void;
  delete(name: string): void;
}

export interface ChainRequest {
  /** 11-byte FCB name of the program the loader was asked to load ("QBCR    COM"). */
  fcbName: string;
  /** "NAME.EXT" form of the same name. */
  name: string;
  /** Command tail at 0080h: the text after the length byte. */
  tail: string;
}

export type StopReason = { kind: "chain"; req: ChainRequest } | { kind: "reboot" } | { kind: "exit" } | { kind: "timeout" };

const TPA_TOP = 0xe406; // value of (0006h): BDOS entry of a typical MSX-DOS 1 disk system
const LOADER = 0xc000; // where the compilers copy their chain loader

export class DosMachine implements Hal {
  tStateCount = 0;
  mem = new Uint8Array(65536);
  cpu: Z80;
  console = "";
  private dma = 0x80;
  private vfs: VFS;
  /** Bytes returned by the "wait for a key" function. */
  keyBuffer: number[] = [13];

  constructor(vfs: VFS) {
    this.vfs = vfs;
    this.cpu = new Z80(this);
  }

  readMemory(a: number): number { return this.mem[a & 0xffff]; }
  writeMemory(a: number, v: number): void { this.mem[a & 0xffff] = v & 0xff; }
  contendMemory(_a: number): void { /* no contention */ }
  readPort(_a: number): number { return 0xff; }
  writePort(_a: number, _v: number): void { /* ignore */ }
  contendPort(_a: number): void { /* no contention */ }

  /** Load a .COM image at 0100h and prepare page zero and the command tail. */
  boot(com: Uint8Array, tail: string): void {
    this.mem.fill(0);
    this.mem.set(com, 0x100);
    this.setTail(tail);
    this.mem[5] = 0xc3; // JP BDOS (intercepted)
    this.mem[6] = TPA_TOP & 0xff;
    this.mem[7] = TPA_TOP >> 8;
    const r = this.cpu.regs;
    r.sp = TPA_TOP - 2 & 0xfffe;
    r.pc = 0x100;
    this.dma = 0x80;
  }

  /** Load another program (what the chain loader does) keeping the command tail. */
  loadProgram(com: Uint8Array): void {
    const tail = this.getTail();
    const keep = this.mem.slice(0xc000); // loader and runtime state do not matter: the compiler starts afresh
    void keep;
    this.mem.fill(0, 0x100, 0xc000);
    this.mem.set(com, 0x100);
    this.setTail(tail);
    const r = this.cpu.regs;
    r.sp = TPA_TOP - 2 & 0xfffe;
    r.pc = 0x100;
    this.dma = 0x80;
  }

  setTail(tail: string): void {
    const t = " " + tail.replace(/^ /, "") + "\r";
    this.mem[0x80] = t.length;
    for (let i = 0; i < t.length; i++) this.mem[0x81 + i] = t.charCodeAt(i);
  }

  getTail(): string {
    const n = this.mem[0x80];
    let s = "";
    for (let i = 0; i < n; i++) {
      const c = this.mem[0x81 + i];
      if (c === 13) break;
      s += String.fromCharCode(c);
    }
    return s.trim();
  }

  private fcbName(fcb: number): string {
    const txt = (a: number, n: number) => String.fromCharCode(...this.mem.slice(a, a + n)).replace(/[\x00-\x20]+$/g, "").replace(/ /g, "");
    const n = txt(fcb + 1, 8).toUpperCase();
    const e = txt(fcb + 9, 3).toUpperCase();
    return e ? `${n}.${e}` : n;
  }

  /** Run until the program asks the loader for another program, reboots, exits, or the step budget is over. */
  run(maxSteps = 400_000_000): StopReason {
    const cpu = this.cpu;
    let steps = 0;
    for (;;) {
      const pc = cpu.regs.pc;
      if (pc === 5) {
        if (!this.bdos()) return { kind: "exit" };
        cpu.regs.pc = cpu.popWord();
        continue;
      }
      if (pc === 0) return { kind: "reboot" };
      if (pc === LOADER) {
        const raw = String.fromCharCode(...this.mem.slice(LOADER + 3, LOADER + 14));
        const nm = raw.slice(0, 8).trim();
        const ex = raw.slice(8, 11).trim();
        return { kind: "chain", req: { fcbName: raw, name: ex ? `${nm}.${ex}` : nm, tail: this.getTail() } };
      }
      cpu.step();
      if (++steps > maxSteps) return { kind: "timeout" };
    }
  }

  /** Handle a BDOS call (function number in C). Returns false when the program terminates. */
  private bdos(): boolean {
    const r = this.cpu.regs;
    const c = r.c;
    const de = r.de;
    const m = this.mem;
    switch (c) {
      case 0x00: return false;
      case 0x01: r.a = this.keyBuffer.length ? this.keyBuffer.shift()! : 13; break;
      case 0x02: this.console += String.fromCharCode(r.e); break;
      case 0x09: {
        let a = de;
        while (m[a] !== 0x24 && a < 0x10000) this.console += String.fromCharCode(m[a++]);
        break;
      }
      case 0x0f: { // open
        const nm = this.fcbName(de);
        const f = this.vfs.read(nm);
        if (!f) { r.a = 0xff; break; }
        m[de + 12] = 0; // extent
        m[de + 14] = 1; m[de + 15] = 0; // record size 1 (the compilers set it again with fcb_rec1)
        const sz = f.length;
        m[de + 16] = sz & 0xff; m[de + 17] = (sz >> 8) & 0xff; m[de + 18] = (sz >> 16) & 0xff; m[de + 19] = (sz >> 24) & 0xff;
        r.a = 0;
        break;
      }
      case 0x10: r.a = 0; break; // close
      case 0x13: this.vfs.delete(this.fcbName(de)); r.a = 0; break;
      case 0x16: this.vfs.write(this.fcbName(de), new Uint8Array(0)); r.a = 0; break; // make
      case 0x1a: this.dma = de; break;
      case 0x23: { // file size (records of 1 byte)
        const f = this.vfs.read(this.fcbName(de));
        const sz = f ? f.length : 0;
        m[de + 33] = sz & 0xff; m[de + 34] = (sz >> 8) & 0xff; m[de + 35] = (sz >> 16) & 0xff;
        r.a = f ? 0 : 0xff;
        break;
      }
      case 0x26: { // random block write
        const nm = this.fcbName(de);
        const old = this.vfs.read(nm) ?? new Uint8Array(0);
        const pos = m[de + 33] | (m[de + 34] << 8) | (m[de + 35] << 16);
        const n = r.hl;
        const size = Math.max(old.length, pos + n);
        const out = new Uint8Array(size);
        out.set(old);
        out.set(m.slice(this.dma, this.dma + n), pos);
        this.vfs.write(nm, out);
        const np = pos + n;
        m[de + 33] = np & 0xff; m[de + 34] = (np >> 8) & 0xff; m[de + 35] = (np >> 16) & 0xff;
        r.a = 0;
        break;
      }
      case 0x27: { // random block read
        const f = this.vfs.read(this.fcbName(de)) ?? new Uint8Array(0);
        const pos = m[de + 33] | (m[de + 34] << 8) | (m[de + 35] << 16);
        const want = r.hl;
        const data = f.subarray(pos, pos + want);
        m.set(data, this.dma);
        const np = pos + data.length;
        m[de + 33] = np & 0xff; m[de + 34] = (np >> 8) & 0xff; m[de + 35] = (np >> 16) & 0xff;
        r.a = data.length === want ? 0 : 1;
        r.hl = data.length;
        break;
      }
      case 0x6f: r.a = 0xff; break; // _DOSVER: not MSX-DOS 2
      default: r.a = 0; break;
    }
    return true;
  }
}
