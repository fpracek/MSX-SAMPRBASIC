@echo off
rem SamPr Basic su MSX2: Philips NMS 8250 (V9938, testo a 80 colonne) con MSX-DOS 1.03.
rem Il disco A: e' la cartella disco_prova. Dal prompt A>:  SAMPRBAS HELLO   e F5 per compilare ed eseguire.
"E:\Dropbox\FAUSTO\SVILUPPI\MSX\EMULATORI\openMSX\openmsx.exe" -machine Philips_NMS_8250 -diska "%~dp0disco_prova" -command "set fullspeedwhenloading on"
