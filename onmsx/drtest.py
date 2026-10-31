#!/usr/bin/env python3
"""Debugger su cartuccia: compila dtests/<nome>.bas (OPTION TARGET ...) e avvia la ROM con i tasti di dtests/<nome>.keys.
uso: python drtest.py nome"""
import os, shutil, subprocess, sys
import qtest
from qtest import BUILD, DISK, HERE
name = sys.argv[1]
qtest.build_all()
src = open(os.path.join(HERE, 'dtests', name + '.bas')).read()
qtest.run_cases([(name, src)], wait_run=40)
rom = os.path.join(DISK, name.lower() + '.rom')
shutil.copy(rom, os.path.join(BUILD, name + '.rom'))
import re
tg = re.search(r'OPTION\s+TARGET\s+(\w+)', src, re.I).group(1).upper()
ROMTYPE = {'ROM16': 'Mirrored', 'ROM32': 'Normal', 'ASCII8': 'ASCII8', 'ASCII16': 'ASCII16', 'KONAMI': 'Konami', 'SCC': 'KonamiSCC'}
tcl = qtest.TCL.replace('proc dump {name} {', 'proc dumpx {name} {') + r'''
proc dump {n} {
    set data [debug read_block VRAM 0 960]
    binary scan $data c* bytes
    set f [open "BUILDDIR/$n.txt" w]
    set row ""; set k 0
    foreach b $bytes {
        set b [expr {$b & 255}]
        if {$b >= 32 && $b < 127} { append row [format %c $b] } else { append row " " }
        incr k
        if {$k == 40} { puts $f $row; set row ""; set k 0 }
    }
    close $f
}
'''.replace('BUILDDIR', BUILD.replace(chr(92), '/'))
tcl += '''
set S {}
proc samp {n} {
    global S
    lappend S [format %04X [reg PC]]
    if {$n > 0} { after time 0.25 [list samp [expr {$n - 1}]] }
}
proc sampdump {fn} { global S; set f [open $fn w]; puts $f $S; close $f }
'''
lines = [tcl]
last = 0
for l in open(os.path.join(HERE, 'dtests', name + '.keys')):
    l = l.rstrip('\n')
    if not l:
        continue
    t, txt = l.split(' ', 1)
    t = float(t); last = max(last, t)
    if txt.startswith('PC'):
        pf = BUILD.replace(chr(92), '/') + '/' + name + '_pc' + txt[2:] + '.txt'
        lines.append('after time %.1f {set f [open "' % t + pf + '" w]; puts $f [format "PC=%04X SP=%04X slot=%s" [reg PC] [reg SP] [debug read memory 0xF3B0]]; close $f}')
    elif txt.startswith('DUMP'):
        lines.append('after time %.1f {dump %s_%s}' % (t, name, txt.split()[1]))
    else:
        lines.append('after time %.1f {type "%s"}' % (t, txt.replace('SPACE', ' ').replace('ENTER', chr(92) + 'r')))
lines.append('after time %.1f exit' % (last + 2))
open(os.path.join(BUILD, 'drtest.tcl'), 'w').write('\n'.join(lines))
for f in os.listdir(BUILD):
    if f.startswith(name + '_') and f.endswith('.txt'):
        os.remove(os.path.join(BUILD, f))
subprocess.run([qtest.OPENMSX, '-machine', os.environ.get('GMACHINE', 'Philips_NMS_8250'), '-cart', os.path.join(BUILD, name + '.rom'),
                '-romtype', ROMTYPE[tg], '-script', os.path.join(BUILD, 'drtest.tcl')], timeout=300)
for f in sorted(os.listdir(BUILD)):
    if f.startswith(name + '_') and f.endswith('.txt'):
        print('=====', f)
        print(open(os.path.join(BUILD, f)).read().rstrip())
