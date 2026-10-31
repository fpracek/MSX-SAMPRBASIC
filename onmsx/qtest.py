#!/usr/bin/env python3
"""Test del compilatore su MSX (QBC.COM) in openMSX/MSX-DOS 1: compila i sorgenti, li esegue
sul DOS emulato e confronta lo schermo con i .exp. uso: python qtest.py [nome ...]"""
import os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, 'build')
DISK = os.path.join(BUILD, 'disk')
TESTS = os.path.join(HERE, '..', 'tests')
QTESTS = os.path.join(HERE, 'qtests')
SJASM = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\sjasmplus-1.20.3.win\sjasmplus.exe'
OPENMSX = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\EMULATORI\openMSX\openmsx.exe'
DOSDIR = r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\DISK2'
FAILS = 0


def check(c, m):
    global FAILS
    print(('  ok   ' if c else '  FAIL ') + m)
    if not c:
        FAILS += 1


def sj(*args):
    r = subprocess.run([SJASM, *args], cwd=HERE, capture_output=True, text=True)
    if r.returncode != 0 or 'error' in r.stdout.lower().replace('0 errors', ''):
        print(r.stdout, r.stderr)
        sys.exit(2)


def build_all():
    sj('--raw=build/ldr.bin', 'ldr.asm')
    sj('--raw=build/rt.bin', 'rtcom.asm')
    sj('--sym=build/qbc.sym', 'qbc.asm')
    sj('--raw=build/qbstub.com', 'qbstub.asm')


TCL = r'''
set throttle off
catch {set renderer none}
proc dump {name} {
    global OUTDIR
    set w [debug read memory 0xF3B0]
    if {$w == 0} { set w 40 }
    set data [debug read_block VRAM 0 [expr {$w * 24}]]
    binary scan $data c* bytes
    set f [open "$OUTDIR/$name.txt" w]
    set row ""; set n 0
    foreach b $bytes {
        set b [expr {$b & 255}]
        if {$b >= 32 && $b < 127} { append row [format %c $b] } else { append row " " }
        incr n
        if {$n == $w} { puts $f $row; set row ""; set n 0 }
    }
    close $f
}
'''


def run_cases(cases, wait_run=float(os.environ.get('QWAIT', '28'))):
    """cases = [(basfile_contenuto, nome)]; ritorna {nome: [righe]}"""
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
    for name, src in cases:
        open(os.path.join(DISK, name.upper() + '.BAS'), 'wb').write(src.replace('\n', '\r\n').encode('latin-1'))
        lines.append('after time %.1f {type "QBC %s.BAS\\r"}' % (t, name.upper()))
        for k in (10, 20, 30, 45, 60):
            if k < wait_run:
                lines.append('after time %.1f {dump %s_m%d}' % (t + k, name, k))
        kf = os.path.join(QTESTS, name + '.keys')
        if os.path.exists(kf):                       # tasti per INPUT: battuti quando il programma e' partito
            lines.append('after time %.1f {type "%s"}' % (t + 9.0, open(kf).read().replace(chr(10), chr(92) + 'r')))
        t += wait_run
        lines.append('after time %.1f {dump %s}' % (t, name))
        t += 1.0
        # il programma attende un tasto e poi torna al QB.COM di prova (che resta fermo): riavvio del DOS
        lines.append('after time %.1f {keymatrixdown 7 128; after time 0.15 {keymatrixup 7 128}}' % t)
        t += 3.0
        lines.append('after time %.1f {dump %s_after}' % (t, name))
        t += 1.0
        lines.append('after time %.1f {reset}' % t)
        t += 20.0
    lines.append('after time %.1f exit' % (t + 1))
    tcl = os.path.join(BUILD, 'qtest.tcl')
    open(tcl, 'w').write('\n'.join(lines))
    for f in os.listdir(BUILD):
        if f.endswith('.txt'):
            os.remove(os.path.join(BUILD, f))
    subprocess.run([OPENMSX, '-machine', os.environ.get('GMACHINE', 'Philips_NMS_8250'), '-diska', DISK, '-script', tcl], timeout=1200)
    out = {}
    for name, _ in cases:
        for suf in ('', '_after'):
            p = os.path.join(BUILD, name + suf + '.txt')
            out[name + suf] = [l.rstrip() for l in open(p)] if os.path.exists(p) else None
    return out


def main():
    build_all()
    comsz = os.path.getsize(os.path.join(BUILD, 'qbc.com'))
    print('QBC.COM = %d byte' % comsz)
    sel = sys.argv[1:]
    cases, exps = [], {}
    for n in ('t1', 't6', 't7'):
        src = open(os.path.join(TESTS, n + '.bas')).read()
        cases.append((n, src))
        exps[n] = [l.rstrip() for l in open(os.path.join(TESTS, n + '.exp')).read().rstrip('\n').split('\n')]
    if os.path.isdir(QTESTS):
        for f in sorted(os.listdir(QTESTS)):
            if f.endswith('.bas'):
                n = f[:-4]
                cases.append((n, open(os.path.join(QTESTS, f)).read()))
                exps[n] = [l.rstrip() for l in open(os.path.join(QTESTS, n + '.exp')).read().rstrip('\n').split('\n')]
    if sel:
        cases = [c for c in cases if c[0] in sel]
    res = run_cases(cases)
    for name, _ in cases:
        print('---', name)
        rows = res.get(name)
        if rows is None:
            check(False, 'nessun dump')
            continue
        exp = exps[name]
        got = [r for r in rows]
        if exp and exp[0].startswith('ERR'):
            want = exp[0][4:].replace('T.BAS', name.upper() + '.BAS')
            flat = re.sub(r'\s+', ' ', ' '.join(r for r in got if not r.startswith('PC ')))
            check(('QBSTUB:' + want + '<end>').replace(' ', '') in flat.replace(' ', ''), 'errore atteso %r; schermo: %r' % (want, flat[-40:]))
            continue
        ok = got[:len(exp)] == exp
        check(ok, 'output uguale a quello atteso')
        if not ok:
            for i in range(max(len(exp), 6)):
                print('   exp %-30r got %r' % (exp[i] if i < len(exp) else '<->', got[i] if i < len(got) else '<->'))
        check(any('Press any key' in r for r in got), 'fine programma: "Press any key"')
        aft = res.get(name + '_after') or []
        check(any('QBSTUB: NAME'.split()[0] in r and name.upper() + '.BAS' in r for r in aft),
              'ritorno all\'editor con ' + name.upper() + '.BAS: ' + ' '.join(r for r in aft if 'QBSTUB' in r)[:60])
    print('FALLITI: %d' % FAILS)
    sys.exit(1 if FAILS else 0)


if __name__ == '__main__':
    main()
