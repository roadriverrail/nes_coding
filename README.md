# NES coding exploration

This is a project covering my exploration of coding 6502 assembly for the NES.

The goal isn't to produce a game, per se, but to hopefully learn to work with
the NES architecture, tools for producing ROMS, etc.  These little "lab
sessions" should be accessible to anyone with some modest background in systems
programming.

These are developed on KDE Neon (Linux), and the Makefile may not work for
Windows.

You will need a copy of [cc65](https://github.com/cc65/cc65) built and
installed.  My preferred emulator/debugger is
[mednafen](https://mednafen.github.io/releases/), which on Ubuntu systems can be
installed with a simple `sudo apt-get install mednafen`.

To build and run:
```
make
mednafen bin/<name_of_rom>.nes
```
