@echo off

set root=%cd%
set opts=-debug -o:none

if not exist build mkdir build
pushd build
del dino_debug.pdb > NUL 2> NUL
rc /nologo /fodino_resources.res %root%\source\dino_resources.rc
odin build %root%\source %opts% -out:dino_debug.exe -extra-linker-flags:"dino_resources.res"
del *.res > NUL 2> NUL
popd
