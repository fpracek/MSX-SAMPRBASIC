#!/usr/bin/env python3
"""Prova su MSX1 (openMSX, Sony HB-75P) delle cartucce gia' compilate da rtest.py (build/rN.rom): confronta il testo a schermo
(40 colonne) con rtests/rN.exp. uso: python m1rom.py [nome ...]"""
import os, re, subprocess, sys
import qtest, rtest

BUILD, RTESTS = qtest.BUILD, rtest.RTESTS
MACHINE = os.environ.get('GMACHINE', 'Sony_HB-75P')
fails = 0
names = sys.argv[1:] or sorted((f[:-4] for f in os.listdir(RTESTS) if f.endswith('.bas')), key=lambda s: int(s[1:]))
for n in names:
    src = open(os.path.join(RTESTS, n + '.bas')).read()
    tg = rtest.target_of(src)
    rom = os.path.join(BUILD, n + '.rom')
    tcl = os.path.join(BUILD, 'm1rom.tcl')
    open(tcl, 'w').write(qtest.TCL + '\nset OUTDIR "%s"\nafter time 16 {dump %s_m1}\nafter time 17 exit\n' % (BUILD.replace(chr(92), '/'), n))
    p = os.path.join(BUILD, n + '_m1.txt')
    if os.path.exists(p):
        os.remove(p)
    subprocess.run([qtest.OPENMSX, '-machine', MACHINE, '-cart', rom, '-romtype', rtest.ROMTYPE[tg], '-script', tcl], timeout=300,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    rows = [l.rstrip() for l in open(p)] if os.path.exists(p) else []
    exp = [l.rstrip() for l in open(os.path.join(RTESTS, n + '.exp')).read().rstrip('\n').split('\n')]
    ok = rows[:len(exp)] == exp
    print(('  ok   ' if ok else '  FAIL ') + f'{n} ({tg}) su {MACHINE}')
    if not ok:
        fails += 1
        for i, e in enumerate(exp[:6]):
            print('     exp %-30r got %r' % (e, rows[i] if i < len(rows) else '<->'))
print('FALLITI: %d' % fails)
