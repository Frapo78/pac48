# PAC48

PAC48 is an open-source **Pac-Man–like game engine** for the **ZX Spectrum 48K**, written entirely in **Z80 assembly**. It aims to be faithful to classic 8-bit constraints while staying cleanly structured, modular, and welcoming to contributors—including AI-assisted ones.

PAC48 is **not a clone** of the original Pac-Man; it is a learning-oriented and extensible framework inspired by classic arcade mechanics.

---

## Target Platform

- **Machine:** ZX Spectrum 48K
- **CPU:** Zilog Z80
- **Video:** Bitmap + attribute memory
- **Input:** Keyboard (Q/A/O/P), Kempston joystick, Sinclair joystick
- **Load address:** `ORG 32768`

The code is designed to remain compatible with **real hardware**, not just emulators.

---

## Project Structure

```
pac48/
├─ src/
│  ├─ main.asm      ; Entry point and main loop
│  ├─ config.asm    ; Global constants (ports, colors, addresses)
│  ├─ memory.asm    ; RAM layout and variables
│  ├─ menu.asm      ; Start menu and control selection
│  ├─ input.asm     ; Keyboard and joystick input handling
│  ├─ video.asm     ; Screen, attributes, rendering helpers
│  ├─ maze.asm      ; Maze data and collision logic
│  └─ player.asm    ; Player (Pac-like) movement and logic
│
├─ assets/
│  └─ sprites.asm   ; Sprite data (planned / WIP)
│
├─ build/
│  ├─ pac48.bin
│  └─ pac48.tap
│
├─ tools/
│  └─ build.sh      ; Build script
│
├─ docs/
│  ├─ memory-map.md
│  ├─ controls.md
│  └─ roadmap.md
│
├─ AGENTS.md        ; Instructions for AI agents (Codex)
├─ README.md
└─ .gitignore
```

Each module has **one clear responsibility**. This structure is intentional and must be preserved.

---

## Build Instructions

### Requirements

- **sjasmplus** (Z80 assembler)
- **Python 3** with **SkoolKit** (for `bin2tap.py`)
- A ZX Spectrum emulator (e.g., **Fuse**) or real hardware

### Build

From the project root:

```bash
sjasmplus src/main.asm build/pac48.bin
bin2tap.py -o 32768 -s 32768 -c 32767 build/pac48.bin build/pac48.tap
```

Or simply:

```bash
./tools/build.sh
```

---

## Controls

At startup, the game displays a menu allowing you to select the control method:

1. Keyboard (Q = up, A = down, O = left, P = right)
2. Kempston joystick
3. Sinclair joystick 1
4. Sinclair joystick 2

Input handling is abstracted via a single routine (`Input_Read`) to keep gameplay code independent from the control method.

---

## Design Goals

- 48K-safe: no 128K features, no bank switching
- Modular Z80 code: readable, commented, maintainable
- Deterministic behavior: suitable for real hardware
- Incremental complexity: start simple, evolve step by step
- AI-friendly layout: designed to work well with Codex and other agents

---

## License

This project is released under the GNU General Public License (GPL).

You are free to:

- study the code
- modify it
- redistribute it
- build your own games on top of it

As long as derivative works remain GPL-compatible. See the `LICENSE` file for details.

---

## Contributing

Contributions are welcome. Please:

- respect the existing module boundaries
- keep changes focused and minimal
- avoid mixing responsibilities across files
- document non-obvious Z80 tricks or optimizations

For AI-assisted contributions, see `AGENTS.md`.

---

## Roadmap (short term)

- Sprite-based player rendering (16×16)
- Pellet system and scoring
- Enemy (ghost) movement and basic AI
- Sound effects (beeper / AY optional)
- Performance optimizations

---

## Why PAC48?

PAC48 is both a learning project for low-level game development and a practical base for real ZX Spectrum games. It is written with care, clarity, and respect for the hardware.

Have fun hacking it.
