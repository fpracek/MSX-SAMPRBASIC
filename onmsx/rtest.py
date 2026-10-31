#!/usr/bin/env python3
"""Test delle cartucce ROM: compila i sorgenti di rtests/ con QBC->QBCR su openMSX/MSX-DOS 1, poi avvia le ROM
prodotte (-cart) in un'altra istanza e confronta il testo a schermo con i .exp. uso: python rtest.py [nome ...]"""
import os, re, shutil, subprocess, sys
import qtest

HERE = qtest.HERE
BUILD = qtest.BUILD
DISK = qtest.DISK
RTESTS = os.path.join(HERE, 'rtests')
ROMTYPE = {'ROM_16': 'Normal', 'ROM_32': 'Normal', 'ROM_ASCII8': 'ASCII8', 'ROM_ASCII16': 'ASCII16', 'ROM_KONAMI': 'Konami', 'ROM_SCC': 'KonamiSCC', 'ROM_KONAMISCC': 'KonamiSCC',
           'ROM16': 'Normal', 'ROM32': 'Normal', 'ASCII8': 'ASCII8', 'ASCII16': 'ASCII16', 'KONAMI': 'Konami', 'SCC': 'KonamiSCC'}
FAILS = 0


def check(c, m):
    global FAILS
    print(('  ok   ' if c else '  FAIL ') + m)
    if not c:
        FAILS += 1


def target_of(src):
    m = re.search(r'OPTION\s+TARGET\s+(\w+)', src, re.I)
    return m.group(1).upper() if m else 'ROM32'


def main():
    qtest.build_all()
    names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(RTESTS) if f.endswith('.bas'))
    cases = [(n, open(os.path.join(RTESTS, n + '.bas')).read()) for n in names]
    for i in range(0, len(cases), 6):                  # a gruppi: le ROM riempirebbero il disco virtuale (720 KB) e le ultime non si scriverebbero
        qtest.run_cases(cases[i:i + 6], wait_run=float(os.environ.get('QWAIT', '40')))
        for n, _ in cases[i:i + 6]:
            rom = os.path.join(DISK, n.lower() + '.rom')
            if os.path.exists(rom):
                shutil.copy(rom, os.path.join(BUILD, n + '.rom'))
            elif os.path.exists(os.path.join(BUILD, n + '.rom')):
                os.remove(os.path.join(BUILD, n + '.rom'))
    for n, src in cases:
        print('---', n)
        rom = os.path.join(BUILD, n + '.rom')
        if not os.path.exists(rom):
            check(False, 'ROM non prodotta')
            continue
        tg = target_of(src)
        tcl = os.path.join(BUILD, 'rtest.tcl')
        open(tcl, 'w').write(qtest.TCL + '\nset OUTDIR "%s"\nafter time 16 {dump %s_rom}\nafter time 18 exit\n' % (BUILD.replace(chr(92), '/'), n))
        subprocess.run([qtest.OPENMSX, '-machine', os.environ.get('GMACHINE', 'Philips_NMS_8250'), '-cart', os.path.join(BUILD, n + '.rom'),
                        '-romtype', ROMTYPE[tg], '-script', tcl], timeout=300)
        p = os.path.join(BUILD, n + '_rom.txt')
        rows = [l.rstrip() for l in open(p)] if os.path.exists(p) else []
        exp = [l.rstrip() for l in open(os.path.join(RTESTS, n + '.exp')).read().rstrip('\n').split('\n')]
        # il dump parte dalla riga 0 dello schermo di testo
        got = [r for r in rows]
        ok = got[:len(exp)] == exp
        check(ok, f'{tg}: schermo uguale a quello atteso')
        if not ok:
            for i, e in enumerate(exp):
                g = got[i] if i < len(got) else '<->'
                print('   exp %-30r got %r' % (e, g))
    print('FALLITI: %d' % FAILS)
    sys.exit(1 if FAILS else 0)


if __name__ == '__main__':
    main()
