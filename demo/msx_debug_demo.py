#!/usr/bin/env python3
"""Records the on-MSX debugger (OPTION DEBUG) with openMSX's recorder. Writes msx_dbg_raw.avi and msx_dbg_marks.json."""
import json, os, shutil, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OPENMSX = os.environ.get('OPENMSX', r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\EMULATORI\openMSX\openmsx.exe')
OUT = os.path.join(HERE, 'msx_dbg_raw.avi')

PROGRAM = [
    "OPTION DEBUG",
    "s = 0",
    "FOR i = 1 TO 5",
    "    s = s + i",
    "NEXT i",
    "t$ = \"SUM\"",
    "CALL show(s)",
    "PRINT t$; s",
    "END",
    "SUB show(n)",
    "    m = n * 2",
    "    PRINT m",
    "END SUB",
    "",
]

disk = tempfile.mkdtemp(prefix='demo-dbg-')
sd = os.path.join(ROOT, 'sample_disk')
for f in os.listdir(sd):
    if f.upper() in ('PONG.SPB', 'PONG.COM', 'PONGFAST.COM'):
        continue
    shutil.copy(os.path.join(sd, f), disk)
open(os.path.join(disk, 'DBGDEMO.SPB'), 'wb').write('\r\n'.join(PROGRAM).encode())

BS = chr(92)
CR = BS + 'r'
EV = []
MARK = {}


def at(t, tcl):
    EV.append((t, tcl))


def typ(t, s):
    at(t, 'type "' + s + '"')


T0 = 16.0
at(0, 'set throttle off')
at(T0, f'record start -doublesize "{OUT.replace(os.sep, "/")}"')
typ(20.0, 'SAMPRBAS DBGDEMO.SPB' + CR)
MARK['editor'] = 30.0
at(34.0, 'keymatrixdown 7 2')            # F5: compile; the program starts stopped in the debugger
at(34.1, 'keymatrixup 7 2')
MARK['f5'] = 34.0
MARK['debugger'] = 60.0                    # compilation takes ~22 s of emulated time
t = 62.0
MARK['step'] = t
for _ in range(7):                         # one statement at a time
    typ(t, ' ')
    t += 1.3
MARK['bp'] = t + 0.5
typ(t + 0.5, 'b' + ' 11' + CR)             # breakpoint inside the SUB
typ(t + 3.5, 'r')                          # run to the breakpoint
MARK['insub'] = t + 6.5
typ(t + 9.5, 'e')                          # inspect any variable
typ(t + 11.0, 'n' + CR)
MARK['eval'] = t + 11.0
typ(t + 15.0, 'e')
typ(t + 16.0, 's' + CR)
typ(t + 20.0, 'q')                         # end the program
MARK['end'] = t + 24.0
at(MARK['end'], 'record stop')
at(MARK['end'] + 1, 'exit')

tcl = ''.join(f'after time {tt:.2f} {{{c}}}\n' for tt, c in sorted(EV, key=lambda e: e[0]))
script = disk + '_s.tcl'
open(script, 'w').write(tcl)
if os.path.exists(OUT):
    os.remove(OUT)
subprocess.run([OPENMSX, '-machine', 'Philips_NMS_8250', '-diska', disk, '-script', script], timeout=900)
marks = {k: round(v - T0, 2) for k, v in MARK.items()}
json.dump(marks, open(os.path.join(HERE, 'msx_dbg_marks.json'), 'w'))
print('video marks', marks)
print(OUT, os.path.getsize(OUT) if os.path.exists(OUT) else 'missing')
