# Independent ZX Spectrum 48K emulator smoke test

The existing SkoolKit harnesses test controls, runtime, contention and TAP loading. This additional workflow runs the assembled game in a separate ZenZX emulator core.

On PRs and manual dispatch, the workflow builds PAC48, builds ZenZX headless and runs 120 frames with the binary loaded at 0x8000 in 48K mode. The screenshot and emulator log are retained for seven days.

Local usage: install/build ZenZX headless, run `./tools/build.sh`, then `ZENZX_BIN=/path/to/zenzx-headless bash tools/run_zenzx_smoke.sh`.

**Verification limits:** the smoke test checks emulator execution and screenshot generation, not pixel correctness, keyboard input, collision behaviour, or whether gameplay reaches a specific state. Do not report those as passed. This independent emulator integration must be validated by a real GitHub Actions run before considering it production-ready. Keep Fuse/manual hardware testing for releases.

The upstream ZenZX dependency is currently fetched from its default branch. Pin a reviewed commit SHA before treating this as a reproducible long-term CI dependency.
