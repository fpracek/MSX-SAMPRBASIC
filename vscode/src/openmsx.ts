// Launching the compiled program in openMSX (DOS program, MSX-BASIC BIN file, ROM cartridge).
import * as cp from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

export interface LaunchConfig {
  openmsx: string;
  machine: string;
  extension: string;
  fullSpeed: boolean;
  dosFiles: string;
  askDate: boolean;
}

export function romTypeFor(mainSource: string): string {
  const m = /OPTION\s+TARGET\s+(\w+)/i.exec(mainSource);
  const t = m ? m[1].toUpperCase() : "ROM_32";
  if (/ASCII8/.test(t)) return "ASCII8";
  if (/ASCII16/.test(t)) return "ASCII16";
  if (/KONAMISCC|SCC/.test(t)) return "KonamiSCC";
  if (/KONAMI/.test(t)) return "Konami";
  return "Normal";
}

function spawnMsx(cfg: LaunchConfig, args: string[], tcl?: string): cp.ChildProcess {
  const exe = cfg.openmsx && cfg.openmsx.trim() ? cfg.openmsx.trim() : "openmsx";
  const full = ["-machine", cfg.machine];
  if (cfg.extension) full.push("-ext", cfg.extension);
  full.push(...args);
  const extra = process.env.SPB_TEST_TCL ?? ""; // test hook: extra Tcl appended to the start-up script
  if (tcl || extra) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "spb-msx-"));
    const script = path.join(dir, "start.tcl");
    fs.writeFileSync(script, (tcl ?? "") + extra);
    full.push("-script", script);
  }
  const dbg = !!process.env.SPB_DEBUG;
  if (dbg) console.log(exe, full.join(" "), tcl ?? "");
  const child = cp.spawn(exe, full, { detached: !dbg, stdio: dbg ? "inherit" : "ignore" });
  child.unref();
  return child;
}

const fsFlag = (cfg: LaunchConfig) => (cfg.fullSpeed ? 'catch {set fullspeedwhenloading on}\n' : "");

/** Boot the machine fast, then slow down to real time just before typing (the boot takes about 20 emulated seconds). */
function typeScript(cfg: LaunchConfig, bootSeconds: number, lines: string[]): string {
  let t = "set throttle off\n" + fsFlag(cfg);
  let at = bootSeconds;
  lines.forEach((ln, i) => {
    t += `after time ${at} {${i === 0 ? "set throttle on; " : ""}type "${ln}\\r"}\n`;
    at += 2;
  });
  return t;
}

export function launchRom(cfg: LaunchConfig, romPath: string, mainSource: string): cp.ChildProcess {
  return spawnMsx(cfg, ["-cart", romPath, "-romtype", romTypeFor(mainSource)]);
}

/** BIN: a disk with only NAME.BIN boots Disk BASIC; the script loads and runs the file. */
export function launchBin(cfg: LaunchConfig, binPath: string): cp.ChildProcess {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "spb-disk-"));
  const name = path.basename(binPath).toUpperCase();
  fs.copyFileSync(binPath, path.join(dir, name));
  const tcl = typeScript(cfg, 24, ["CLEAR 200,&H83FF", `BLOAD\\"${name}\\",R`]);
  return spawnMsx(cfg, ["-diska", dir], tcl);
}

/** DOS: the project folder is the disk (like the real one), so it needs MSXDOS.SYS and COMMAND.COM next to the program. */
export function launchDos(cfg: LaunchConfig, projectDir: string, comName: string): cp.ChildProcess | string {
  if (!cfg.dosFiles) return "Set 'samprbasic.dosFiles' to the folder that holds MSXDOS.SYS and COMMAND.COM (needed to run DOS programs; they are not included).";
  const pick = (f: string) => {
    const dir = fs.readdirSync(cfg.dosFiles);
    return dir.find((x) => x.toUpperCase() === f);
  };
  const sys = pick("MSXDOS.SYS");
  const cmd = pick("COMMAND.COM");
  if (!sys || !cmd) return `MSXDOS.SYS and COMMAND.COM were not found in ${cfg.dosFiles}.`;
  for (const f of [sys, cmd]) {
    const have = fs.readdirSync(projectDir).some((x) => x.toUpperCase() === f.toUpperCase());
    if (!have) fs.copyFileSync(path.join(cfg.dosFiles, f), path.join(projectDir, f.toUpperCase()));
  }
  for (const f of ["MSXDOS2.SYS", "COMMAND2.COM"]) {
    const src = pick(f);
    if (src && !fs.readdirSync(projectDir).some((x) => x.toUpperCase() === f)) fs.copyFileSync(path.join(cfg.dosFiles, src), path.join(projectDir, f));
  }
  const prog = path.basename(comName, path.extname(comName)).toUpperCase();
  const lines = cfg.askDate ? ["1-1-86", prog] : [prog];
  return spawnMsx(cfg, ["-diska", projectDir], typeScript(cfg, 22, lines));
}
