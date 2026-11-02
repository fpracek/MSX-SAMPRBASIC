#!/usr/bin/env python3
"""Runs a sample from the on-MSX editor (F5) in openMSX and takes screenshots. usage: ide_test.py NAME.SPB t1,t2,..."""
import os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OPENMSX = os.environ.get('OPENMSX', r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\EMULATORI\openMSX\openmsx.exe')
name = sys.argv[1]
times = [float(x) for x in sys.argv[2].split(',')]
extra = os.environ.get('EXTRA_TCL', '')
shots = os.path.join(HERE, 'shots')
os.makedirs(shots, exist_ok=True)
for f in os.listdir(shots):
    os.remove(os.path.join(shots, f))
disk = tempfile.mkdtemp(prefix='ide-')
sd = os.path.join(ROOT, 'sample_disk')
for f in os.listdir(sd):
    if f.upper() in ('PONG.COM', 'PONGFAST.COM', 'GEOMRUN.COM'):
        continue
    shutil.copy(os.path.join(sd, f), disk)
BS = chr(92)
tcl = 'set throttle off\nset minframeskip 0\nset maxframeskip 0\n'
tcl += 'after time 20 {type "SAMPRBAS ' + name + BS + 'r"}\n'
tcl += 'after time 34 {keymatrixdown 7 2}\nafter time 34.1 {keymatrixup 7 2}\n'
for i, t in enumerate(times):
    tcl += 'after time %g {screenshot "%s/i%d_%g.png"}\n' % (t, shots.replace(os.sep, '/'), i, t)
tcl += extra
tcl += 'after time %g {exit}\n' % (max(times) + 3)
script = disk + '_s.tcl'
open(script, 'w').write(tcl)
subprocess.run([OPENMSX, '-machine', 'Philips_NMS_8250', '-diska', disk, '-script', script], timeout=900)
print(sorted(os.listdir(shots)))
