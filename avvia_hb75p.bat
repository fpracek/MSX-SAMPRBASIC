@echo off
rem SamPr Basic su MSX1: Sony HB-75P (TMS9918, testo a 40 colonne) con MSX-DOS 1.03.
rem L'interfaccia disco e' la Panasonic FS-FD1A; il disco A: e' la cartella disco_prova (accanto a questo file).
rem All'avvio il DOS chiede la data ("Enter new date:"): premi INVIO. Poi:  SAMPRBAS HELLO   e F5 per compilare ed eseguire.
rem "fullspeedwhenloading" fa andare l'emulatore alla massima velocita' durante gli accessi al disco.
"E:\Dropbox\FAUSTO\SVILUPPI\MSX\EMULATORI\openMSX\openmsx.exe" -machine Sony_HB-75P -ext Panasonic_FS-FD1A -diska "%~dp0disco_prova" -command "set fullspeedwhenloading on"
