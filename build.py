#!/usr/bin/env python3
"""Compiles a .bas, assembles it, runs it in headless openMSX (NMS-8250 = MSX2)
and compares the screen (VRAM name table, 80 columns) with the .exp file.

usage: python build.py tests/t1.bas [--keep]
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SJASM = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\sjasmplus-1.20.3.win\sjasmplus.exe'
OPENMSX = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\EMULATORI\openMSX\openmsx.exe'
MACHINE = 'Philips_NMS_8250'

sys.path.insert(0, HERE)
import qbc  # noqa: E402

TCL = r'''
set throttle off
proc dump {} {
    set f [open "%(out)s" w]
    set data [debug read_block VRAM 0 1920]
    binary scan $data c* bytes
    set row ""
    set n 0
    foreach b $bytes {
        set b [expr {$b & 255}]
        if {$b < 32 || $b > 126} { set b 46 }
        append row [format %%c $b]
        incr n
        if {$n == 80} { puts $f [string trimright $row]; set row ""; set n 0 }
    }
    close $f
    exit
}
%(keys)s
after time %(secs)d dump
'''


def run(bas, secs=40, keys=''):
    name = os.path.splitext(os.path.basename(bas))[0]
    bd = os.path.join(HERE, 'build', name)
    os.makedirs(bd, exist_ok=True)
    asm = os.path.join(bd, name + '.asm')
    src = open(bas, encoding='latin-1').read()
    try:
        text = qbc.compile_source(src)
    except qbc.CompileError as e:
        print('ERRORE DI COMPILAZIONE:', e)
        return None
    open(asm, 'w', encoding='latin-1', newline='\n').write(text)
    r = subprocess.run([SJASM, f'--inc={HERE}', f'--sym={name}.sym', asm],
                       cwd=bd, capture_output=True, text=True)
    if r.returncode != 0 or 'error:' in (r.stdout + r.stderr).lower():
        print(r.stdout, r.stderr)
        return None
    rom = os.path.join(bd, name + '.rom')
    os.replace(os.path.join(bd, 'out.rom'), rom)
    out = os.path.join(bd, name + '.out')
    if os.path.exists(out):
        os.remove(out)
    tcl = os.path.join(bd, name + '.tcl')
    open(tcl, 'w').write(TCL % {'out': out.replace('\\', '/'), 'secs': secs, 'keys': keys})
    subprocess.run([OPENMSX, '-machine', MACHINE, '-carta', rom, '-script', tcl],
                   timeout=180)
    if not os.path.exists(out):
        print('nessun dump prodotto')
        return None
    return open(out).read().rstrip('\n').split('\n')


if __name__ == '__main__':
    bas = sys.argv[1]
    kp = os.path.splitext(bas)[0] + '.keys'
    lines = run(bas, keys=open(kp).read() if os.path.exists(kp) else '')
    if lines is None:
        sys.exit(2)
    while lines and not lines[-1]:
        lines.pop()
    exp_path = os.path.splitext(bas)[0] + '.exp'
    if os.path.exists(exp_path):
        exp = [l.rstrip() for l in open(exp_path).read().rstrip('\n').split('\n')]
        # the screen may contain initial BIOS lines: compare the first lines
        ok = lines[:len(exp)] == exp
        print('OK' if ok else 'DIFFERENZE')
        if not ok:
            for i in range(max(len(exp), len(lines))):
                a = exp[i] if i < len(exp) else '<->'
                b = lines[i] if i < len(lines) else '<->'
                print(('  ' if a == b else '! ') + f'{i:2d} atteso={a!r} ottenuto={b!r}')
        sys.exit(0 if ok else 1)
    print('\n'.join(lines))
