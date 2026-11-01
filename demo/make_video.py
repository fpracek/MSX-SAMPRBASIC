#!/usr/bin/env python3
"""Assembles demo/SamPrBasic-demo.mp4 from the two raw recordings (vscode_raw.mp4, msx_raw.avi):
cuts, speed-ups for the waiting parts, English captions and title cards."""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
FF = open(os.path.join(HERE, 'ffpath.txt')).read().strip()
FONT = 'C\\:/Windows/Fonts/segoeui.ttf'
OUT = os.path.join(HERE, 'SamPrBasic-demo.mp4')
W, H, FPS = 1920, 1080, 25

vm = {}
for line in open(os.path.join(HERE, 'vscode_marks.txt')):
    k, v = line.split()
    vm[k] = int(v)
vt = {k: (v - vm['ffmpeg']) / 1000.0 for k, v in vm.items()}
mm = json.load(open(os.path.join(HERE, 'msx_marks.json')))

# (input, start, end, speed, caption)
SEG = [
    (0, 5.0, vt['typing'], 1.5, 'VS Code with the SamPr Basic extension - same files as on the MSX'),
    (0, vt['typing'], vt['error'], 1.6, 'Syntax colors while you type'),
    (0, vt['error'], vt['hover'], 1.0, 'Errors from the real compiler appear as you type'),
    (0, vt['hover'], vt['run'], 1.0, 'Hover help for every statement'),
    (0, vt['run'], vt['run'] + 13.0, 3.0, 'F5: compile with the real QBC.COM and run in openMSX'),
    (0, vt['run'] + 13.0, vt['ran'], 1.0, 'The program runs on the emulated MSX'),
    (0, vt['ran'], vt['stopped'], 3.0, 'Ctrl+F5: source-level debugger (breakpoint on line 8)'),
    (0, vt['stopped'], vt['paused'] + 0.5, 1.0, 'Stopped at the breakpoint: variables, call stack, step over, continue, pause'),
]
MSEG = [
    (1, 0.0, mm['editor'], 2.0, 'On an MSX2 (openMSX) with MSX-DOS: start the SamPr Basic editor'),
    (1, mm['editor'], mm['scroll'], 1.0, '80 columns, keywords in color, file and edit menus'),
    (1, mm['scroll'], mm['f5'], 2.0, 'The same project, running on the MSX itself'),
    (1, mm['f5'], mm['game'], 6.0, 'F5: the compiler runs on the MSX and produces Z80 machine code'),
    (1, mm['game'], mm['anykey'], 1.0, '...and the program starts. Cursor keys move the paddle, ESC quits'),
    (1, mm['anykey'], mm['help'], 2.0, 'Back to the editor'),
    (1, mm['help'], mm['helpshown'], 2.0, 'F6: help on the word under the cursor'),
    (1, mm['helpshown'], mm['helpshown'] + 8.0, 1.0, 'Online help on the MSX'),
]

CARDS = {
    'intro': ('SamPr Basic', 'A BASIC to Z80 compiler and IDE for MSX', 3.5),
    'p1': ('Part 1', 'VS Code extension on the PC', 2.5),
    'p2': ('Part 2', 'On the MSX itself (openMSX)', 2.5),
    'outro': ('github.com/fpracek/MSX-SAMPRBASIC', 'Compiler, editor, debugger, VS Code extension, manual', 4.0),
}


def esc(t):
    return t.replace('\\', '\\\\').replace(':', '\\:').replace("'", '').replace('%', '\\%')


chains = []
labels = []


def card(name, i):
    title, sub, dur = CARDS[name]
    lab = f'c{i}'
    chains.append(
        f"color=c=0x1a1aa8:s={W}x{H}:r={FPS}:d={dur},format=yuv420p,"
        f"drawtext=fontfile='{FONT}':text='{esc(title)}':fontsize=84:fontcolor=white:x=(w-text_w)/2:y=h/2-90,"
        f"drawtext=fontfile='{FONT}':text='{esc(sub)}':fontsize=40:fontcolor=0xffe14d:x=(w-text_w)/2:y=h/2+30,setsar=1[{lab}]")
    labels.append(f'[{lab}]')


def seg(idx, s, a, b, speed, cap):
    lab = f's{idx}'
    if a == 0 and False:
        pass
    crop = 'crop=1470:876:0:0,' if s == 0 else ''
    scale = f'scale=-2:{H}:flags=lanczos' if s == 0 else f'scale=1440:{H}:flags=neighbor'
    chains.append(
        f"[{s}:v]trim=start={a:.3f}:end={b:.3f},setpts=(PTS-STARTPTS)/{speed},fps={FPS},{crop}{scale},"
        f"pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:color=black,format=yuv420p,"
        f"drawtext=fontfile='{FONT}':text='{esc(cap)}':fontsize=38:fontcolor=white:box=1:boxcolor=black@0.65:boxborderw=14:x=(w-text_w)/2:y=h-90,setsar=1[{lab}]")
    labels.append(f'[{lab}]')


n = 0
card('intro', n); n += 1
card('p1', n); n += 1
for s, a, b, sp, cap in SEG:
    seg(n, s, a, b, sp, cap); n += 1
card('p2', n); n += 1
for s, a, b, sp, cap in MSEG:
    seg(n, s, a, b, sp, cap); n += 1
card('outro', n); n += 1

graph = ';\n'.join(chains) + ';\n' + ''.join(labels) + f'concat=n={len(labels)}:v=1:a=0[v]'
gp = os.path.join(HERE, 'graph.txt')
open(gp, 'w', encoding='utf-8').write(graph)
cmd = [FF, '-y', '-loglevel', 'error', '-stats', '-i', os.path.join(HERE, 'vscode_raw.mp4'), '-i', os.path.join(HERE, 'msx_raw.avi'),
       '-filter_complex_script', gp, '-map', '[v]', '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', OUT]
subprocess.run(cmd, check=True)
print(OUT, os.path.getsize(OUT))
