@echo off

set root=%cd%
set opts=-debug

if not exist dir build mkdir build
pushd build
odin build %opts% %root%\source -out:dino.exe
popd
