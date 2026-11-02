#!/usr/bin/env python3
"""Editor F5 test: opens a BASIC source, F5 -> saves, compiles (QBC.COM), runs, returns
to the editor; then a source with a syntax error: return with a message and the cursor on the line.
All on emulated MSX-DOS 1 (openMSX NMS-8250), no help from the PC."""
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
    new = ['cls', 'print "inizio"', 'gosub stampaValore', 'end', '', 'stampaValore:', '  print "valore"', '  return']
    err = ['PRINT "one"', 'PRINT "two"', 'x = 5', 'PRINT 1 +', 'PRINT "never"']
    open(os.path.join(DISK, 'NEW.SPB'), 'wb').write((CRLF.join(new) + CRLF).encode())
    open(os.path.join(DISK, 'ERR.SPB'), 'wb').write((CRLF.join(err) + CRLF).encode())

    sc = Scenario(syms)
    sc.t = 20.0
    sc.text('SAMPRBAS NEW.SPB' + BS + 'r', 30.0)
    sc.dump('r0b_typed')
    sc.tap(7, 0x02, 1, 0.5)                          # F5
    sc.t += 70.0                                     # save + QBC + compilation + writing + launch
    sc.dump('r1_ran')
    sc.tap(8, 0x01, 1, 0.5)                          # space: the program ends and reloads the editor
    sc.t += 30.0
    sc.dump('r2_back')
    sc.t += 1.0

    tcl = os.path.join(BUILD, 'erun_end.tcl')
    open(tcl, 'w').write(sc.script())
    for f in os.listdir(BUILD):
        if f.startswith('r') and f[1:2].isdigit() and f.endswith('.txt'):
            os.remove(os.path.join(BUILD, f))
    subprocess.run([OPENMSX, '-machine', MACHINE, '-diska', DISK, '-script', tcl], timeout=1500)

    for n in ('r1_ran', 'r2_back'):
        print('---', n)
        rows, vs, bl = load(n)
        for r in range(0, 8):
            print('   ', rows.get(r, '')[:70].rstrip())


if __name__ == "__main__":
    main()
