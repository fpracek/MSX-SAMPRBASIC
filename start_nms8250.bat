@echo off
rem SamPr Basic on MSX2: Philips NMS 8250 (V9938, 80-column text) with MSX-DOS 1.03.
rem Drive A: is the "sample_disk" folder next to this file (copy MSXDOS.SYS and COMMAND.COM into it).
rem At the A> prompt:  SAMPRBAS HELLO   and F5 to compile and run.
rem Set OPENMSX to the full path of openmsx.exe if it is not in your PATH.
if "%OPENMSX%"=="" set OPENMSX=openmsx
"%OPENMSX%" -machine Philips_NMS_8250 -diska "%~dp0sample_disk" -command "set fullspeedwhenloading on"
