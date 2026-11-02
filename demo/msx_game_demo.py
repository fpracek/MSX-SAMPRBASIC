#!/usr/bin/env python3
"""Records GEOMRUN on the MSX (from the editor, F5) with openMSX's recorder.
The jumps are pressed by a Tcl script that reads the sprite attribute table in VRAM (the game itself is untouched).
At the end CTRL+STOP (OPTION BREAK) returns to the editor. Writes msx_game_raw.avi and msx_game_marks.json."""
import json, os, shutil, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OPENMSX = os.environ.get('OPENMSX', r'E:\Dropbox\FAUSTO\SVILUPPI\MSX\EMULATORI\openMSX\openmsx.exe')
OUT = os.path.join(HERE, 'msx_game_raw.avi')
MARKS = os.path.join(HERE, 'msx_game_marks.json').replace(os.sep, '/')
PLAY_SECONDS = 42

disk = tempfile.mkdtemp(prefix='demo-game-')
sd = os.path.join(ROOT, 'sample_disk')
for f in os.listdir(sd):
    if f.upper() in ('PONG.SPB', 'PONG.COM', 'PONGFAST.COM', 'GEOMRUN.COM', 'PONGFAST.SPB'):
        continue
    shutil.copy(os.path.join(sd, f), disk)

BS = chr(92)
T0 = 16.0
tcl = f'''
set throttle off
set ::marks [dict create]
proc mark {{name}} {{ dict set ::marks $name [expr {{[machine_info time] - {T0}}}] }}
proc save_marks {{}} {{
  set f [open "{MARKS}" w]
  puts $f "{{"
  set first 1
  dict for {{k v}} $::marks {{ if {{!$first}} {{puts $f ","}}; set first 0; puts -nonewline $f "\\"$k\\": [format %.2f $v]" }}
  puts $f "\\n}}"
  close $f
}}
proc space {{}} {{ keymatrixdown 8 1; after time 0.08 {{keymatrixup 8 1}} }}
set ::state wait
set ::tplay 0
set ::lastjump 0
proc bot {{}} {{
  set now [machine_info time]
  set c [vpeek 6251]               ;# row 3, col 11: E = title, G = game over, 134 = stars (playing)
  if {{$::state eq "wait"}} {{
    if {{$c == 69}} {{ set ::state title; set ::t_title $now; mark title }}
  }} elseif {{$::state eq "title"}} {{
    if {{$now - $::t_title > 2.5}} {{ space; set ::state play; set ::tplay $now; if {{![info exists ::tfirst]}} {{ set ::tfirst $now; mark play }} }}
  }} elseif {{$::state eq "play"}} {{
    if {{$c == 71}} {{
      if {{![info exists ::t_over]}} {{ set ::t_over $now }}
      if {{$now - $::t_over > 3.0}} {{ space; unset ::t_over; set ::state title; set ::t_title $now }}
    }} else {{
      set obs {{}}
      for {{set p 3}} {{$p <= 8}} {{incr p}} {{
        set a [expr {{7680 + $p * 4}}]
        if {{[vpeek $a] == 209}} continue
        set x [vpeek [expr {{$a + 1}}]]
        if {{$x > 66}} {{ lappend obs [list $x [vpeek $a]] }}
      }}
      if {{[llength $obs] > 0 && $now - $::lastjump > 0.3}} {{
        set obs [lsort -integer -index 0 $obs]
        set x0 [lindex $obs 0 0]
        set tall 0
        set prev $x0
        foreach o $obs {{
          if {{[lindex $o 0] - $prev > 17}} break
          set prev [lindex $o 0]
          if {{[lindex $o 1] < 120}} {{ set tall 1 }}
        }}
        set spd [expr {{6 + int(($now - $::tplay) / 22)}}]
        if {{$spd > 10}} {{ set spd 10 }}
        set thr [expr {{$tall ? 4 * $spd + 6 : 2 * $spd + 5}}]
        if {{$x0 - 80 <= $thr}} {{ space; set ::lastjump $now }}
      }}
    }}
    if {{[info exists ::tfirst] && $now - $::tfirst > {PLAY_SECONDS} && $::state eq "play"}} {{
      set ::state done
      mark brk
      keymatrixdown 6 2; keymatrixdown 7 16
      after time 0.6 {{keymatrixup 7 16; keymatrixup 6 2}}
      after time 21 {{ mark end; save_marks; record stop; exit }}
    }}
  }}
  after time 0.02 bot
}}
after time {T0} {{record start -doublesize "{OUT.replace(os.sep, '/')}"}}
after time 20 {{type "SAMPRBAS GEOMRUN.SPB{BS}r"}}
after time 30 {{mark editor}}
after time 40 {{keymatrixdown 7 2; mark f5}}
after time 40.1 {{keymatrixup 7 2}}
after time 60 bot
'''
script = disk + '_s.tcl'
open(script, 'w').write(tcl)
if os.path.exists(OUT):
    os.remove(OUT)
subprocess.run([OPENMSX, '-machine', 'Philips_NMS_8250', '-diska', disk, '-script', script], timeout=1500)
print(open(MARKS).read() if os.path.exists(MARKS) else 'no marks')
print(OUT, os.path.getsize(OUT) if os.path.exists(OUT) else 'missing')
