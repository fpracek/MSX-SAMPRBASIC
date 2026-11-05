#!/usr/bin/env python3
"""ROM debugger with variables (OPTION DEBUG GLOBALS / ALL) on the 3-segment cartridge GEOMR (sample_disk/GEOMR00x.SPB).
usage: python drgeom.py [GLOBALS|ALL]   -> shows the debugger screen at the start and after running to a breakpoint inside segment 1."""
import os, shutil, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OPENMSX = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\EMULATORI\openMSX\openmsx.exe'
level = sys.argv[1] if len(sys.argv) > 1 else 'ALL'
bp = sys.argv[2] if len(sys.argv) > 2 else '12'
tools = os.path.join(ROOT, 'vscode', 'tools')
sys.path.insert(0, os.path.join(ROOT, 'vscode'))
d = tempfile.mkdtemp(prefix='drgeom-')
for n in ('GEOMR000', 'GEOMR001', 'GEOMR002'):
    t = open(os.path.join(ROOT, 'sample_disk', n + '.SPB'), encoding='latin1').read().replace('\r\n', '\n')
    if n == 'GEOMR000':
        # hooks only from here on (and in the other segments): the fixed segment is too small for hooks everywhere
        t = t.replace('quit:\n', 'OPTION DEBUG %s\nquit:\n' % level, 1)
    open(os.path.join(d, n + '.SPB'), 'w', encoding='latin1', newline='').write(t.replace('\n', '\r\n'))
js = r'''
const lib=require(%r);const r=lib.compile(%r,%r,"GEOMR000.SPB");console.log(JSON.stringify({ok:r.ok,out:r.output,diag:r.diagnostics}));''' % (
    os.path.join(ROOT, 'vscode', 'dist', 'compile.cjs'), d, tools)
print(subprocess.run(['node', '-e', js], capture_output=True, text=True).stdout)
out = d.replace('\\', '/')
tcl = '''
set throttle off
proc dump {n} {
    binary scan [debug read_block VRAM 0 960] c* bytes
    set f [open "%s/$n.txt" w]
    set row ""; set k 0
    foreach b $bytes {
        set b [expr {$b & 255}]
        if {$b >= 32 && $b < 127} { append row [format %%c $b] } else { append row " " }
        incr k
        if {$k == 40} { puts $f $row; set row ""; set k 0 }
    }
    close $f
}
after time 12 {dump first}
after time 14 {type "B"}
after time 15 {type "%s\\r"}
after time 17 {type "r"}
after time 30 {dump bp}
after time 32 {type "v"}
after time 34 {dump page2}
after time 40 exit
''' % (out, bp)
open(os.path.join(d, 't.tcl'), 'w').write(tcl)
subprocess.run([OPENMSX, '-machine', 'Philips_NMS_8250', '-cart', os.path.join(d, 'GEOMR.ROM'), '-romtype', 'ASCII16', '-script', os.path.join(d, 't.tcl')], timeout=300)
for n in ('first', 'bp', 'page2'):
    p = os.path.join(d, n + '.txt')
    print('=====', n)
    print(open(p).read().rstrip() if os.path.exists(p) else 'missing')
