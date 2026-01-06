# AGENTS.md – PAC48

This project is a Pac-Man–like game for **ZX Spectrum 48K**, written in **Z80 assembly**.

## Target
- Machine: ZX Spectrum 48K
- CPU: Z80
- Screen: bitmap + attributes
- Entry point: ORG 32768

## Build
Assembler: **sjasmplus**

Build commands:
sjasmplus src/main.asm build/pac48.bin
bin2tap.py -o 32768 -s 32768 -c 32767 build/pac48.bin build/pac48.tap

## Project structure
src/
main.asm      ; entry point and main loop
config.asm    ; constants, ports, colors
memory.asm    ; RAM layout and variables
menu.asm      ; start menu and control selection
input.asm     ; keyboard / joystick input
video.asm     ; screen, attributes, sprites
maze.asm      ; maze data and collision
player.asm    ; Pac-Man logic and movement
assets/
sprites.asm   ; sprite data
build/
pac48.bin
pac48.tap

## Coding rules for agents

- **Do NOT change** ORG address (32768)
- **Do NOT mix modules**: each file has one responsibility
- Modify **only the relevant module**
- Do not inline code from one module into another
- Keep Z80 code compatible with **48K only**
- Avoid ROM calls unless explicitly requested

## Game logic notes

- Movement is tile-based (for now)
- Rendering uses attribute cells
- Input is abstracted via `Input_Read`
- Main loop is in `main.asm`

## What agents may safely do

- Improve or refactor a single module
- Add new routines inside the correct file
- Optimize Z80 code
- Add comments and documentation

## What agents must NOT do

- Rewrite the whole project
- Change memory layout without explicit instruction
- Introduce external libraries
