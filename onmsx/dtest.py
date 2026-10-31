#!/usr/bin/env python3
"""Debugger (OPTION DEBUG) su openMSX: compila dtests/<nome>.bas, invia i tasti di dtests/<nome>.keys
(riga: secondi dopo l'avvio, testo) e salva gli schermi TEXT 40x24 in build/<nome>_<n>.txt.
uso: python dtest.py nome"""
import os, shutil, subprocess, sys
import qtest
from qtest import BUILD, DISK, HERE, OPENMSX

name = sys.argv[1]
qtest.build_all()
for f in ('MSXDOS.SYS', 'COMMAND.COM'):
    shutil.copy(os.path.join(qtest.DOSDIR, f), DISK)
for f in os.listdir(DISK):
    if f.upper().endswith(('.BAS', '.COM', '.ROM')) and f.upper() not in ('QBC.COM', 'QBCR.COM', 'SAMPRBAS.COM', 'COMMAND.COM'):
        os.remove(os.path.join(DISK, f))
shutil.copy(os.path.join(BUILD, 'qbc.com'), os.path.join(DISK, 'QBC.COM'))
shutil.copy(os.path.join(BUILD, 'qbstub.com'), os.path.join(DISK, 'SAMPRBAS.COM'))
shutil.copy(os.path.join(BUILD, 'qbcr.com'), os.path.join(DISK, 'QBCR.COM'))
shutil.copy(os.path.join(BUILD, 'rt.bin'), os.path.join(DISK, 'RT.BIN'))
shutil.copy(os.path.join(BUILD, 'rtrom.bin'), os.path.join(DISK, 'RTROM.BIN'))
shutil.copy(os.path.join(BUILD, 'rtd.bin'), os.path.join(DISK, 'RTD.BIN'))
shutil.copy(os.path.join(BUILD, 'qasm.ovl'), os.path.join(DISK, 'QASM.OVL'))
shutil.copy(os.path.join(BUILD, 'rtromd.bin'), os.path.join(DISK, 'RTROMD.BIN'))
src = open(os.path.join(HERE, 'dtests', name + '.bas')).read()
open(os.path.join(DISK, name.upper() + '.BAS'), 'wb').write(src.replace('\n', '\r\n').encode('latin-1'))
tcl = r'''
set throttle off
catch {set renderer none}
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
proc samp {n} {
    global S
    lappend S [format %04X [reg PC]]
    if {$n > 0} { after time 0.0137 [list samp [expr {$n - 1}]] }
}
proc vsum {fn} {
    set data [debug read_block VRAM 0 16384]
    binary scan $data c* bytes
    set f [open $fn w]
    puts $f [join $bytes ,]
    set regs {}
    for {set i 0} {$i < 8} {incr i} { lappend regs [debug read memory [expr {0xF3DF + $i}]] }
    puts $f $regs
    close $f
}
proc sampdump {fn} { global S; set f [open $fn w]; puts $f $S; close $f }
'''
lines = [tcl, 'after time 20 {type "QBC %s.BAS' % name.upper() + chr(92) + 'r"}']
last = 20
for l in open(os.path.join(HERE, 'dtests', name + '.keys')):
    l = l.rstrip('\n')
    if not l:
        continue
    t, txt = l.split(' ', 1)
    t = float(t) + 20
    last = max(last, t)
    if txt.startswith('PC'):
        pf = BUILD.replace(chr(92), '/') + '/' + name + '_pc' + txt[2:] + '.txt'
        lines.append('after time %.1f {set f [open "' % t + pf + '" w]; puts $f [format "PC=%04X SP=%04X" [reg PC] [reg SP]]; close $f}')
    elif txt.startswith('VSUM'):
        lines.append('after time %.1f {vsum "' % t + BUILD.replace(chr(92), '/') + '/' + name + '_vsum' + txt[4:] + '.txt"}')
    elif txt.startswith('SAMP'):
        lines.append('set S {}; after time %.1f {samp 60}' % t)
        lines.append('after time %.1f {sampdump "' % (t + 1.5) + BUILD.replace(chr(92), '/') + '/' + name + '_samp' + txt[4:] + '.txt"}')
    elif txt.startswith('DUMP'):
        lines.append('after time %.1f {dump %s_%s}' % (t, name, txt.split()[1]))
    else:
        txt = txt.replace('SPACE', ' ').replace('ENTER', chr(92) + 'r')
        txt = txt.replace('$', chr(92) + '$')       # Tcl: "N$(1)" sarebbe una variabile
        lines.append('after time %.1f {type "%s"}' % (t, txt))
lines.append('after time %.1f exit' % (last + 3))
open(os.path.join(BUILD, 'dtest.tcl'), 'w').write('\n'.join(lines))
for f in os.listdir(BUILD):
    if f.startswith(name + '_') and f.endswith('.txt'):
        os.remove(os.path.join(BUILD, f))
subprocess.run([OPENMSX, '-machine', os.environ.get('GMACHINE', 'Philips_NMS_8250'), '-diska', DISK,
                '-script', os.path.join(BUILD, 'dtest.tcl')], timeout=600)
for f in sorted(os.listdir(BUILD)):
    if f.startswith(name + '_') and f.endswith('.txt'):
        print('=====', f)
        print(open(os.path.join(BUILD, f)).read().rstrip())
