@echo off
bin\debug\premake5.exe ^
--scripts=modules ^
--file=modules\vscode\tests\premake5.lua ^
vscode %*
