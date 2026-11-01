@echo off
rem SamPr Basic on MSX1: Sony HB-75P (TMS9918, 40-column text) with MSX-DOS 1.03.
rem Drive A: is the "sample_disk" folder next to this file (copy MSXDOS.SYS and COMMAND.COM into it).
rem At startup DOS asks for the date ("Enter new date:"): press ENTER. Then:  SAMPRBAS HELLO   and F5 to compile and run.
rem Set OPENMSX to the full path of openmsx.exe if it is not in your PATH.
rem "fullspeedwhenloading" runs the emulator at full speed during disk access.
if "%OPENMSX%"=="" set OPENMSX=openmsx
"%OPENMSX%" -machine Sony_HB-75P -ext Panasonic_FS-FD1A -diska "%~dp0sample_disk" -command "set fullspeedwhenloading on"
