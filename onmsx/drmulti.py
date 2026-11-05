#!/usr/bin/env python3
"""ROM debugger with variables (OPTION DEBUG GLOBALS / ALL) on a small 2-segment cartridge (ASCII16).
usage: python drmulti.py [GLOBALS|ALL|NONE]  -> debugger screens: at the start (globals) and at a breakpoint inside segment 1 (locals).
The test is considered passed when the screen texts contain the expected variables (checked at the end)."""
import os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OPENMSX = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\EMULATORI\openMSX\openmsx.exe'
level = sys.argv[1] if len(sys.argv) > 1 else 'ALL'
tools = os.path.join(ROOT, 'vscode', 'tools')

F0 = """OPTION TARGET ROM_ASCII16
OPTION LABELS
OPTION DEBUG %s
DIM arr(3)
total = 7
name$ = "HELLO"
CALL work(5, "AB")
PRINT total
END
""" % ('' if level == 'NONE' else level)
F1 = """' segment 1: the routine to be debugged (statements on lines 10-14)
'
'
'
'
'
'
'
'
SUB work(n, s$)
 SHARED total
 k = n * 2
 total = total + k
 PRINT s$
END SUB
"""
d = tempfile.mkdtemp(prefix='drmulti-')
for n, t in (('MULTI000', F0), ('MULTI001', F1)):
    open(os.path.join(d, n + '.SPB'), 'w', encoding='latin1', newline='').write(t.replace('\n', '\r\n'))
js = r'''
const lib=require(%r);const r=lib.compile(%r,%r,"MULTI000.SPB");console.log(JSON.stringify({ok:r.ok,out:r.output,diag:r.diagnostics}));''' % (
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
after time 13 {type "B"}
after time 14 {type "13\\r"}
after time 15 {type "r"}
after time 18 {dump bp}
after time 20 exit
''' % out
open(os.path.join(d, 't.tcl'), 'w').write(tcl)
subprocess.run([OPENMSX, '-machine', 'Philips_NMS_8250', '-cart', os.path.join(d, 'MULTI.ROM'), '-romtype', 'ASCII16', '-script', os.path.join(d, 't.tcl')], timeout=300)
texts = {}
for n in ('first', 'bp'):
    p = os.path.join(d, n + '.txt')
    texts[n] = open(p).read() if os.path.exists(p) else ''
    print('=====', n)
    print(texts[n].rstrip() or 'missing')
ok = True
def check(name, cond):
    global ok
    print(('ok   ' if cond else 'FAIL ') + name)
    ok = ok and cond
if level == 'NONE':
    check('no variable table', 'NO VARIABLE TABLE' in texts['first'])
else:
    check('globals at start: TOTAL=0', 'TOTAL=0' in texts['first'])
    check('globals at start: NAME$=""', 'NAME$=""' in texts['first'])
    check('breakpoint in segment 1: line 13', 'LINE 13' in texts['bp'])
    check('global changed: TOTAL=7 still', 'TOTAL=7' in texts['bp'])
    if level == 'ALL':
        check('local N=5', '>N=5' in texts['bp'])
        check('local S$="AB"', '>S$="AB"' in texts['bp'])
        check('local K=10', '>K=10' in texts['bp'])
print('PASSED' if ok else 'FAILED')
sys.exit(0 if ok else 1)
