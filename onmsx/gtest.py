#!/usr/bin/env python3
"""Test della grafica (SCREEN 5-8) su openMSX / MSX-DOS 1: compila e avvia i programmi di gtests/,
poi legge la VRAM e controlla i pixel indicati nei file .chk.
Formato .chk: 'mode N' poi righe 'px X Y C' (il pixel vale C) oppure 'px X Y !C' (diverso da C).
uso: python gtest.py [nome ...]"""
import os
import shutil
import subprocess
import sys

import qtest
from qtest import BUILD, DISK, HERE, OPENMSX, DOSDIR, build_all

GTESTS = os.path.join(HERE, 'gtests')
FAILS = 0
VRAM_BYTES = 0xD400


def check(c, m):
    global FAILS
    print(('  ok   ' if c else '  FAIL ') + m)
    if not c:
        FAILS += 1


TCL = r'''
set throttle off
catch {set renderer none}
proc vdump {name} {
    global OUTDIR
    set data [debug read_block VRAM 0 %d]
    set f [open "$OUTDIR/$name.vram" wb]
    puts -nonewline $f $data
    close $f
    set data [debug read_block "VDP palette" 0 32]
    set f [open "$OUTDIR/$name.pal" wb]
    puts -nonewline $f $data
    close $f
}
''' % VRAM_BYTES


def pixel(v, mode, x, y):
    if mode == 5:
        b = v[y * 128 + x // 2]
        return b >> 4 if x % 2 == 0 else b & 15
    if mode == 6:
        b = v[y * 128 + x // 4]
        return (b >> (6 - 2 * (x % 4))) & 3
    if mode == 7:
        b = v[y * 256 + x // 2]
        return b >> 4 if x % 2 == 0 else b & 15
    if mode == 8:
        return v[y * 256 + x]
    raise ValueError(mode)


def run_cases(names, wait=30.0):
    if os.path.isdir(DISK):
        shutil.rmtree(DISK)
    os.makedirs(DISK)
    for f in ('MSXDOS.SYS', 'COMMAND.COM'):
        shutil.copy(os.path.join(DOSDIR, f), DISK)
    shutil.copy(os.path.join(BUILD, 'qbc.com'), os.path.join(DISK, 'QBC.COM'))
    shutil.copy(os.path.join(BUILD, 'qbstub.com'), os.path.join(DISK, 'QB.COM'))
    lines = [TCL, 'set OUTDIR "%s"' % BUILD.replace(chr(92), '/')]
    t = 20.0
    for n in names:
        src = open(os.path.join(GTESTS, n + '.bas')).read()
        open(os.path.join(DISK, n.upper() + '.BAS'), 'wb').write(src.replace('\n', '\r\n').encode('latin-1'))
        lines.append('after time %.1f {type "QBC %s.BAS%sr"}' % (t, n.upper(), chr(92)))
        t += wait
        lines.append('after time %.1f {vdump %s}' % (t, n))
        t += 1.0
        lines.append('after time %.1f {reset}' % t)
        t += 20.0
    lines.append('after time %.1f exit' % (t + 1))
    tcl = os.path.join(BUILD, 'gtest.tcl')
    open(tcl, 'w').write('\n'.join(lines))
    for n in names:
        p = os.path.join(BUILD, n + '.vram')
        if os.path.exists(p):
            os.remove(p)
    subprocess.run([OPENMSX, '-machine', 'Philips_NMS_8250', '-diska', DISK, '-script', tcl], timeout=1500)


def main():
    build_all()
    names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(GTESTS) if f.endswith('.bas'))
    run_cases(names)
    for n in names:
        print('---', n)
        p = os.path.join(BUILD, n + '.vram')
        if not os.path.exists(p):
            check(False, 'nessun dump VRAM')
            continue
        v = open(p, 'rb').read()
        mode = 5
        for ln in open(os.path.join(GTESTS, n + '.chk')):
            w = ln.split()
            if not w or w[0].startswith('#'):
                continue
            if w[0] == 'mode':
                mode = int(w[1])
            elif w[0] == 'pal':
                pal = open(os.path.join(BUILD, n + '.pal'), 'rb').read()
                i, r, g, b = (int(z) for z in w[1:5])
                gr, rb = pal[2 * i + 1] & 7, pal[2 * i]
                check(((rb >> 4) & 7, gr, rb & 7) == (r, g, b), f'palette {i} = {((rb >> 4) & 7, gr, rb & 7)} (atteso {(r, g, b)})')
            elif w[0] in ('any', 'none', 'count'):
                x0, y0, x1, y1, c = (int(z) for z in w[1:6])
                n_ = sum(1 for yy in range(y0, y1 + 1) for xx in range(x0, x1 + 1) if pixel(v, mode, xx, yy) == c)
                if w[0] == 'any':
                    check(n_ > 0, f'rettangolo ({x0},{y0})-({x1},{y1}) contiene il colore {c} ({n_} pixel)')
                elif w[0] == 'none':
                    check(n_ == 0, f'rettangolo ({x0},{y0})-({x1},{y1}) senza il colore {c} ({n_} pixel)')
                else:
                    lo, hi = int(w[6]), int(w[7])
                    check(lo <= n_ <= hi, f'rettangolo ({x0},{y0})-({x1},{y1}): {n_} pixel di colore {c} (attesi {lo}-{hi})')
            elif w[0] == 'px':
                x, y = int(w[1]), int(w[2])
                neg = w[3].startswith('!')
                want = int(w[3].lstrip('!'))
                got = pixel(v, mode, x, y)
                check((got != want) if neg else (got == want),
                      f'pixel ({x},{y}) = {got}' + (f' (atteso diverso da {want})' if neg else f' (atteso {want})'))
    print('FALLITI: %d' % FAILS)
    sys.exit(1 if FAILS else 0)


if __name__ == '__main__':
    main()
