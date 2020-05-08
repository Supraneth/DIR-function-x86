@echo off
c:\masm32\bin\ml /c /Zd /coff ProjetDIR.asm
c:\\masm32\bin\Link /SUBSYSTEM:CONSOLE ProjetDIR.obj
pause
