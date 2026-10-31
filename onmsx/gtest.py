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
VRAM_BYTES = 0x20000


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
    set data [debug read_block memory 0xF3E0 32]
    set f [open "$OUTDIR/$name.ram" wb]
    puts -nonewline $f $data
    close $f
    set data [debug read_block "VDP regs" 0 48]
    set f [open "$OUTDIR/$name.reg" wb]
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
    if mode == 2:
        off = ((y >> 3) << 8) + (x & 0xF8) + (y & 7)
        col = v[0x2000 + off]
        return (col >> 4) if v[off] & (0x80 >> (x & 7)) else (col & 15)
    raise ValueError(mode)


def run_cases(names, wait=50.0):
    if os.path.isdir(DISK):
        shutil.rmtree(DISK)
    os.makedirs(DISK)
    for f in ('MSXDOS.SYS', 'COMMAND.COM'):
        shutil.copy(os.path.join(DOSDIR, f), DISK)
    shutil.copy(os.path.join(BUILD, 'qbc.com'), os.path.join(DISK, 'QBC.COM'))
    shutil.copy(os.path.join(BUILD, 'qbstub.com'), os.path.join(DISK, 'QB.COM'))
    shutil.copy(os.path.join(BUILD, 'rt.bin'), os.path.join(DISK, 'RT.BIN'))
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
    subprocess.run([OPENMSX, '-machine', os.environ.get('GMACHINE', 'Philips_NMS_8250'), '-diska', DISK, '-script', tcl], timeout=1500)


def main():
    build_all()
    plus = 'GMACHINE' in os.environ              # i test p*.bas servono un MSX2+ (es. Panasonic_FS-A1ST)
    names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(GTESTS) if f.endswith('.bas') and (plus or not f.startswith('p')))
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
            elif w[0] == 'sppat1':                      # schermi 1-3: generatore a 3800h
                pn, size = int(w[1]), int(w[2])
                want = [int(z) for z in w[3:]]
                got = list(v[0x3800 + pn * size: 0x3800 + pn * size + len(want)])
                check(got == want, f'pattern {pn} (schermo 1-3): {got} (atteso {want})')
            elif w[0] == 'sp1':                         # schermi 1-3: attributi a 1B00h: Y X pattern colore
                pl = int(w[1])
                want = [int(z) for z in w[2:6]]
                got = list(v[0x1B00 + pl * 4: 0x1B00 + pl * 4 + 4])
                check(got == want, f'sprite {pl} (schermo 1-3): {got} (atteso {want})')
            elif w[0] in ('sppat', 'spat', 'spcol'):
                rg = open(os.path.join(BUILD, n + '.reg'), 'rb').read()
                attr = ((rg[11] & 1) << 15) | ((rg[5] & 0xFC) << 7)
                gen = (rg[6] & 0x1F) << 11
                if w[0] == 'sppat':
                    pn, size = int(w[1]), int(w[2])
                    want = [int(z) for z in w[3:]]
                    got = list(v[gen + pn * size: gen + pn * size + len(want)])
                    check(got == want, f'pattern {pn} ({size} byte) a {gen:04X}: {got} (atteso {want})')
                elif w[0] == 'spat':
                    pl = int(w[1])
                    want = [int(z) for z in w[2:5]]
                    got = list(v[attr + pl * 4: attr + pl * 4 + 3])
                    check(got == want, f'sprite {pl}: Y,X,pattern = {got} (atteso {want}) attributi a {attr:04X}')
                else:
                    pl, cnt, val = int(w[1]), int(w[2]), int(w[3])
                    got = list(v[attr - 0x200 + pl * 16: attr - 0x200 + pl * 16 + cnt])
                    check(got == [val] * cnt, f'colori del sprite {pl}: {got[:4]}... (atteso {val} x{cnt})')
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
            elif w[0] == 'vb':                          # byte di VRAM (anche 64K-128K)
                a, want = int(w[1], 0), int(w[2], 0)
                check(v[a] == want, f'VRAM[{a:05X}] = {v[a]} (atteso {want})')
            elif w[0] == 'vnz':                         # almeno un byte diverso da zero in [ADDR, ADDR+LEN)
                a, ln = int(w[1], 0), int(w[2], 0)
                check(any(v[a:a + ln]), f'VRAM[{a:05X}..+{ln}] contiene dati: {list(v[a:a + ln])}')
            elif w[0] == 'reg':                         # registro del VDP
                rg = open(os.path.join(BUILD, n + '.reg'), 'rb').read()
                r_, want = int(w[1]), int(w[2], 0)
                check(rg[r_] == want, f'R#{r_} = {rg[r_]} (atteso {want})')
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
