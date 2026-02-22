<p align="center">
    <img src="assets/trex.jpg" alt="Game logo." width="125" height="125">
</p>

# dino-game
 Recreation of the offline Google Chrome dinosaur game. Made with Odin & Raylib.

# Build
 Building the game is as simple as invoking the [Odin](https://odin-lang.org/) compiler on the `source` directory: `odin build source`. The provided build scripts act as wrappers for common sets of flags, and on Windows invoke the [Resource compiler](https://learn.microsoft.com/en-us/windows/win32/menurc/resource-compiler) to link the executable with an icon.

```
build.bat          Build with debug info, no optimizations and console output enabled; Link icon through the Resource compiler
build_release.bat  Build with debug info, optimizations and console output disabled; Link icon through the Resource compiler

build.sh           Build with debug info, no optimizations
```

# Reference
 The implementation uses [trex-runner](https://trex-runner.com/) as a reference, mostly for constants and physics, so that the feel is as close to the original as possible. The code structure, however, is completely different.

# Style
 The entire game logic is written inside the `main` function, and is laid out as linearly as possible. [Long functions are preferred](https://cbarrete.com/carmack.html) over short ones. [Naming things is avoided](https://youtu.be/SEp0NrXWwoo?si=r2ptAYG8ExpV-5fI) unless necessary.
