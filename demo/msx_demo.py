#!/usr/bin/env python3
"""Records the MSX side of the demo video with openMSX's built-in recorder (emulated time: smooth even at full speed).
Prints the video-time marks (seconds from the start of the recording) used by make_video.py."""
import json, os, shutil, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OPENMSX = os.environ.get('OPENMSX', r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\EMULATORI\openMSX\openmsx.exe')
OUT = os.path.join(HERE, 'msx_raw.avi')

disk = tempfile.mkdtemp(prefix='demo-disk-')
sd = os.path.join(ROOT, 'sample_disk')
for f in os.listdir(sd):
    if f.upper() in ('PONG.SPB', 'PONG.COM', 'PONGFAST.COM'):
        continue
    shutil.copy(os.path.join(sd, f), disk)

BS = chr(92)
EV = []
KEYS = {'F5': (7, 2), 'ESC': (7, 4), 'UP': (8, 0x20), 'DOWN': (8, 0x40), 'RIGHT': (8, 0x80), 'SPACE': (8, 1)}
MARK = {}


def at(t, tcl):
    EV.append((t, tcl))


def tap(t, row, mask, hold=0.08):
    at(t, f'keymatrixdown {row} {mask}')
    at(t + hold, f'keymatrixup {row} {mask}')


def key(t, name):
    tap(t, *KEYS[name])


def scroll_to_if(t):
    for _ in range(37):             # down to the first IF of the loop
        tap(t, 8, 0x40, 0.05)
        t += 0.15
    for i in range(4):              # onto the word IF
        tap(t + 0.2 * i, 8, 0x80, 0.08)
    return t + 1.2


def help_on_word(t):
    at(t, 'keymatrixdown 6 1')      # Shift+F1 = F6
    at(t + 0.05, 'keymatrixdown 6 32')
    at(t + 0.4, 'keymatrixup 6 32')
    at(t + 0.45, 'keymatrixup 6 1')


T0 = 16.0                           # video time zero = emulated time of "record start"
at(0, 'set throttle off')
at(T0, f'record start -doublesize "{OUT.replace(os.sep, "/")}"')
at(20.0, 'type "SAMPRBAS PONGFAST.SPB' + BS + 'r"')
MARK['editor'] = 30.0
t = 34.0
MARK['scroll'] = t
t = scroll_to_if(t)
t += 1.0
MARK['f5'] = t + 1.0
key(t + 1.0, 'F5')                  # compile and run
MARK['game'] = t + 1.0 + 22.0       # compilation takes ~20 s of emulated time
t_play = MARK['game'] + 2.0
for _ in range(6):
    for d in ('UP', 'DOWN'):
        at(t_play, f'keymatrixdown {KEYS[d][0]} {KEYS[d][1]}')
        at(t_play + 0.9, f'keymatrixup {KEYS[d][0]} {KEYS[d][1]}')
        t_play += 1.2
MARK['esc'] = t_play + 1.0
key(MARK['esc'], 'ESC')
MARK['anykey'] = MARK['esc'] + 3.0
key(MARK['anykey'] + 2.0, 'SPACE')
MARK['back'] = MARK['anykey'] + 8.0
t = MARK['back'] + 2.0
MARK['help'] = t
t = scroll_to_if(t)
help_on_word(t + 0.5)
MARK['helpshown'] = t + 0.5
key(t + 8.0, 'ESC')
t_end = t + 11.0
at(t_end, 'record stop')
at(t_end + 1, 'exit')
MARK['end'] = t_end

tcl = ''.join(f'after time {t:.2f} {{{c}}}\n' for t, c in sorted(EV, key=lambda e: e[0]))
script = disk + '_s.tcl'
open(script, 'w').write(tcl)
if os.path.exists(OUT):
    os.remove(OUT)
subprocess.run([OPENMSX, '-machine', 'Philips_NMS_8250', '-diska', disk, '-script', script], timeout=900)
marks = {k: round(v - T0, 2) for k, v in MARK.items()}
json.dump(marks, open(os.path.join(HERE, 'msx_marks.json'), 'w'))
print('video marks', marks)
print(OUT, os.path.getsize(OUT) if os.path.exists(OUT) else 'missing')
