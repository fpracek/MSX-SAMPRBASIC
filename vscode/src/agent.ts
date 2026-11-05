// A small Tcl agent that runs inside openMSX and talks to the extension through files:
// the extension writes cmd.tcl, the agent evaluates it and writes reply.txt; events (breakpoint hits...) are appended to events.txt.
// (Some openMSX builds, e.g. the Windows one, have no usable -control interface, so files are the portable way.)
import * as cp from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { LaunchConfig } from "./openmsx";

const AGENT_TCL = (dir: string) => `
set ::spb_dir "${dir.split(path.sep).join("/")}"
proc spb_event {args} {
  set f [open "$::spb_dir/events.txt" a]
  puts $f [join $args " "]
  close $f
}
proc spb_hit {} {
  debug break
  spb_event stopped [reg HL] [reg IX] [reg PC]
}
set ::spb_mode 0
set ::spb_sp 0
set ::spb_stopped 0
proc spb_rhit {} {
  if {$::spb_stopped} return
  set ::spb_stopped 1
  debug break
  spb_event stopped [reg HL] [reg IX] [reg PC] [reg SP]
}
proc spb_end {} {
  spb_event ended
}
proc spb_poll {} {
  set f "$::spb_dir/cmd.tcl"
  if {[file exists $f]} {
    set fh [open $f r]
    set code [read $fh]
    close $fh
    file delete $f
    set rc [catch {uplevel #0 $code} res]
    set out [open "$::spb_dir/reply.tmp" w]
    puts $out $rc
    puts -nonewline $out $res
    close $out
    file rename -force "$::spb_dir/reply.tmp" "$::spb_dir/reply.txt"
  }
  after realtime 0.05 spb_poll
}
spb_poll
spb_event ready
`;

export interface AgentEvent { name: string; args: string[]; }

export class MsxAgent {
  readonly dir: string;
  child: cp.ChildProcess | undefined;
  exited = false;
  onEvent: (e: AgentEvent) => void = () => undefined;
  onExit: () => void = () => undefined;
  private eventPos = 0;
  private timer: NodeJS.Timeout | undefined;
  private queue: Promise<unknown> = Promise.resolve();

  constructor() {
    this.dir = fs.mkdtempSync(path.join(os.tmpdir(), "spb-agent-"));
  }

  /** Start openMSX with the agent and the given extra Tcl (typing the program name etc.). */
  start(cfg: LaunchConfig, msxArgs: string[], bootTcl: string): void {
    const exe = cfg.openmsx && cfg.openmsx.trim() ? cfg.openmsx.trim() : "openmsx";
    const args = ["-machine", cfg.machine];
    if (cfg.extension) args.push("-ext", cfg.extension);
    args.push(...msxArgs);
    const script = path.join(this.dir, "start.tcl");
    fs.writeFileSync(script, AGENT_TCL(this.dir) + bootTcl);
    args.push("-script", script);
    this.child = cp.spawn(exe, args, { stdio: "ignore" });
    this.child.on("exit", () => { this.exited = true; this.stopPolling(); this.onExit(); });
    this.child.on("error", () => { this.exited = true; this.stopPolling(); this.onExit(); });
    this.timer = setInterval(() => this.pollEvents(), 40);
  }

  private stopPolling(): void { if (this.timer) { clearInterval(this.timer); this.timer = undefined; } }

  private pollEvents(): void {
    const f = path.join(this.dir, "events.txt");
    let data: string;
    try { data = fs.readFileSync(f, "latin1"); } catch { return; }
    if (data.length <= this.eventPos) return;
    const chunk = data.slice(this.eventPos);
    const end = chunk.lastIndexOf("\n");
    if (end < 0) return;
    this.eventPos += end + 1;
    for (const line of chunk.slice(0, end).split("\n")) {
      const parts = line.trim().split(/\s+/);
      if (parts[0]) this.onEvent({ name: parts[0], args: parts.slice(1) });
    }
  }

  /** Evaluate Tcl inside openMSX and return the result (rejects on a Tcl error or timeout). */
  send(tcl: string, timeoutMs = 20000): Promise<string> {
    const run = () => new Promise<string>((resolve, reject) => {
      if (this.exited) { reject(new Error("openMSX is not running")); return; }
      const cmd = path.join(this.dir, "cmd.tcl");
      const tmp = path.join(this.dir, "cmd.tmp");
      const reply = path.join(this.dir, "reply.txt");
      try { fs.unlinkSync(reply); } catch { /* none */ }
      fs.writeFileSync(tmp, tcl);
      fs.renameSync(tmp, cmd);
      const t0 = Date.now();
      const tick = () => {
        if (this.exited) { reject(new Error("openMSX exited")); return; }
        if (fs.existsSync(reply)) {
          let txt = "";
          try { txt = fs.readFileSync(reply, "latin1"); } catch { setTimeout(tick, 10); return; }
          try { fs.unlinkSync(reply); } catch { /* ignore */ }
          const nl = txt.indexOf("\n");
          const rc = nl < 0 ? txt : txt.slice(0, nl);
          const res = nl < 0 ? "" : txt.slice(nl + 1);
          if (rc.trim() === "0") resolve(res); else reject(new Error(res || "Tcl error"));
          return;
        }
        if (Date.now() - t0 > timeoutMs) { reject(new Error("openMSX did not answer")); return; }
        setTimeout(tick, 15);
      };
      tick();
    });
    const p = this.queue.then(run, run);
    this.queue = p.catch(() => undefined);
    return p;
  }

  /** Read `len` bytes of Z80 memory. */
  async readMem(addr: number, len: number): Promise<Buffer> {
    if (len <= 0) return Buffer.alloc(0);
    const hex = await this.send(`binary scan [debug read_block memory ${addr & 0xffff} ${len}] H* h; set h`);
    return Buffer.from(hex.trim(), "hex");
  }

  async reg(name: string): Promise<number> {
    return parseInt((await this.send(`reg ${name}`)).trim(), 10);
  }

  kill(): void {
    this.stopPolling();
    if (this.child && !this.exited) { try { this.child.kill(); } catch { /* ignore */ } }
  }
}
