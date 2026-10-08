# Independent ZX Spectrum 48K emulator smoke test

The existing SkoolKit harnesses test controls, runtime, contention and TAP loading. This additional workflow runs the assembled game in a separate ZenZX emulator core.

On PRs and manual dispatch, the workflow builds PAC48, builds ZenZX headless and runs 120 frames with the binary loaded at 0x8000 in 48K mode. The screenshot and emulator log are retained for seven days.

Local usage: install/build ZenZX headless, run `./tools/build.sh`, then `ZENZX_BIN=/path/to/zenzx-headless bash tools/run_zenzx_smoke.sh`.

**Verification limits:** the smoke test checks emulator execution and screenshot generation, not pixel correctness, keyboard input, collision behaviour, or whether gameplay reaches a specific state. Do not report those as passed. This independent emulator integration must be validated by a real GitHub Actions run before considering it production-ready. Keep Fuse/manual hardware testing for releases.

The upstream ZenZX dependency is currently fetched from its default branch. Pin a reviewed commit SHA before treating this as a reproducible long-term CI dependency.

## October 2026 direct-binary boot regression

A direct `-bin` entry at 0x8000 does **not** initialize the Spectrum BASIC ROM workspace. Calling ROM `CLS` (0x0DAF) during menu startup caused a uniform screenshot. The menu now clears bitmap and attributes through PAC48's own `Video_Clear` routine. A separate ROM-CLS probe reproduces the unsafe startup behavior, and an independent screen-writing Z80 probe confirms that ZenZX executes binaries correctly.

GitHub Actions emulator run [37768876331](https://github.com/Frapo78/pac48/actions/runs/37768876331) passed with two distinct screenshot colors at frame 120; verification run [37768876328](https://github.com/Frapo78/pac48/actions/runs/37768876328) passed. Early frames 1–12 remain uniform, so this **does not establish** menu layout correctness or gameplay entry. The checker rejects monochrome screenshots, but is not a pixel-reference oracle. ZenZX headless provides no simulated menu keypress in this workflow. Keep manual/interactive checks and avoid interpreting this CI pass as gameplay verification.
