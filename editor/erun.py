#!/usr/bin/env python3
"""Test F5 dell'editor: apre un sorgente BASIC, F5 -> salva, compila (QBC.COM), esegue, ritorna
all'editor; poi un sorgente con un errore di sintassi: ritorno con messaggio e cursore sulla riga.
Tutto su MSX-DOS 1 emulato (openMSX NMS-8250), nessun aiuto dal PC."""
import os
import shutil
import subprocess
import sys

import etest
from etest import Scenario, check, load, BUILD, SJASM, OPENMSX, MACHINE
import ecom

HERE = etest.HERE
ONMSX = os.path.join(HERE, '..', 'onmsx')
DISK = ecom.DISK
CRLF = chr(13) + chr(10)
BS = chr(92)


def main():
    ecom.prepare_disk()
    syms = ecom.assemble_com()
    r = subprocess.run([SJASM, '--sym=build/qbc.sym', 'qbc.asm'], cwd=ONMSX, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout, r.stderr)
        sys.exit(2)
    shutil.copy(os.path.join(ONMSX, 'build', 'qbc.com'), os.path.join(DISK, 'QBC.COM'))
    shutil.copy(os.path.join(ONMSX, 'build', 'rt.bin'), os.path.join(DISK, 'RT.BIN'))
    shutil.copy(os.path.join(HERE, 'ed.com'), os.path.join(DISK, 'SAMPRBAS.COM'))
    new = ['PRINT "Hello from MSXQB"', 'FOR i = 1 TO 3 : PRINT i; : NEXT', 'PRINT']
    err = ['PRINT "one"', 'PRINT "two"', 'x = 5', 'PRINT 1 +', 'PRINT "never"']
    open(os.path.join(DISK, 'NEW.SPB'), 'wb').write((CRLF.join(new) + CRLF).encode())
    open(os.path.join(DISK, 'ERR.SPB'), 'wb').write((CRLF.join(err) + CRLF).encode())

    sc = Scenario(syms)
    sc.t = 20.0
    sc.text('SAMPRBAS NEW.SPB' + BS + 'r', 30.0)
    sc.dump('r0b_typed')
    sc.tap(7, 0x02, 1, 0.5)                          # F5
    sc.t += 70.0                                     # salvataggio + QBC + compilazione + scrittura + avvio
    sc.do('set ::nopatch 1', 0.1)                    # il programma e' in esecuzione: la RAM dell'editor non vale
    sc.dump('r1_ran')
    sc.tap(8, 0x01, 1, 0.5)                          # spazio: il programma termina e ricarica l'editor
    sc.t += 30.0
    sc.do('unset ::nopatch', 0.1)
    sc.dump('r2_back')
    sc.tap(7, 0x02, 1, 0.5)                          # F5 di nuovo: testo invariato e compilato -> rilancia NOME.COM subito
    sc.t += 12.0                                     # (una ricompilazione ne richiederebbe molti di piu')
    sc.do('set ::nopatch 1', 0.1)
    sc.dump('r2c_rerun')
    sc.tap(8, 0x01, 1, 0.5)                          # spazio: ritorna all'editor
    sc.t += 30.0
    sc.do('unset ::nopatch', 0.1)
    sc.dump('r2d_back2')
    ecom.chord(sc, *ecom.CTRL_O, gap=1.0)            # apre ERR.SPB
    sc.text('E', 0.5)
    sc.tap(7, 0x80, 1, 8.0)
    sc.dump('r2b_err_loaded')
    sc.tap(7, 0x02, 1, 0.5)
    sc.t += 70.0
    sc.dump('r3_error')
    sc.t += 1.0

    tcl = os.path.join(BUILD, 'erun.tcl')
    open(tcl, 'w').write(sc.script())
    for f in os.listdir(BUILD):
        if f.startswith('r') and f[1:2].isdigit() and f.endswith('.txt'):
            os.remove(os.path.join(BUILD, f))
    subprocess.run([OPENMSX, '-machine', MACHINE, '-diska', DISK, '-script', tcl], timeout=1500)

    print('--- r0 file aperto da riga di comando')
    rows, vs, bl = load('r0b_typed')
    check(rows[1][:24] == 'PRINT "Hello from MSXQB"' and rows[2].startswith('FOR i = 1 TO 3 : PRINT i; : NEXT'),
          f'sorgente caricato: {rows[1][:30]!r} / {rows[2][:30]!r}')
    print('--- r1 F5: compilato ed eseguito')
    rows, vs, bl = load('r1_ran')
    check(rows[0].startswith('Hello from MSXQB'), f'riga 1 del programma: {rows[0][:30]!r}')
    check(rows[1].startswith(' 1  2  3'), f'riga 2: {rows[1][:20]!r}')
    check(any('Press any key' in r for r in rows.values()), 'attesa tasto a fine programma')
    check(os.path.exists(os.path.join(DISK, 'NEW.COM')) or os.path.exists(os.path.join(DISK, 'new.com')),
          'NEW.COM generato sul disco')
    print("--- r2 ritorno all'editor")
    rows, vs, bl = load('r2_back')
    check(rows[1][:24] == 'PRINT "Hello from MSXQB"' and 'Loaded 64 bytes' in rows[0], f'editor riaperto con il sorgente: {rows[0][:50]!r} {rows[1][:20]!r}')
    check(vs['len'] > 50 and vs['curline'] == 1, f'len={vs["len"]} curline={vs["curline"]}')
    print('--- r2c F5 senza modifiche: rilancia NOME.COM senza ricompilare')
    rows, vs, bl = load('r2c_rerun')
    check(rows[0].startswith('Hello from MSXQB') and rows[1].startswith(' 1  2  3'), f'il programma gira di nuovo: {rows[0][:20]!r}')
    rows, vs, bl = load('r2d_back2')
    check('Loaded' in rows[0] and rows[1][:24] == 'PRINT "Hello from MSXQB"', f"e torna all'editor: {rows[0][:40]!r}")
    print('--- r3 errore di sintassi')
    rows, vs, bl = load('r2b_err_loaded')
    check(rows[4][:9] == 'PRINT 1 +', f'ERR.SPB aperto: {rows[4][:12]!r}')
    rows, vs, bl = load('r3_error')
    t = rows[0].replace('~', '')
    check('Line 4: Syntax error' in t, f'messaggio: {t[:60]!r}')
    check(vs['curline'] == 4, f"cursore sulla riga dell'errore: curline={vs['curline']}")
    check(rows[4][:9] == 'PRINT 1 +', f'riga 4 visibile: {rows[4][:12]!r}')
    print('FALLITI: %d' % etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
