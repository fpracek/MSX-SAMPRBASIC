#!/usr/bin/env python3
"""Test delle cartucce ROM: compila i sorgenti di rtests/ con QBC->QBCR su openMSX/MSX-DOS 1, poi avvia le ROM
prodotte (-cart) in un'altra istanza e confronta il testo a schermo con i .exp. uso: python rtest.py [nome ...]"""
import os, re, shutil, subprocess, sys
import qtest

HERE = qtest.HERE
BUILD = qtest.BUILD
DISK = qtest.DISK
RTESTS = os.path.join(HERE, 'rtests')
ROMTYPE = {'ROM16': 'Normal', 'ROM32': 'Normal', 'ASCII8': 'ASCII8', 'ASCII16': 'ASCII16', 'KONAMI': 'Konami', 'SCC': 'KonamiSCC'}
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
    qtest.run_cases(cases, wait_run=float(os.environ.get('QWAIT', '40')))
    for n, src in cases:
        print('---', n)
        rom = os.path.join(DISK, n.lower() + '.rom')
        if not os.path.exists(rom):
            check(False, 'ROM non prodotta')
            continue
        shutil.copy(rom, os.path.join(BUILD, n + '.rom'))
        tg = target_of(src)
        tcl = os.path.join(BUILD, 'rtest.tcl')
        open(tcl, 'w').write(qtest.TCL + '\nset OUTDIR "%s"\nafter time 12 {dump %s_rom}\nafter time 14 exit\n' % (BUILD.replace(chr(92), '/'), n))
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
