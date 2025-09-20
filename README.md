# Lean SDL3 Bindings Example

Playing around with SDL3 bindings in Lean4 to learn about the FFI.

Simple real-time Doom-style raycasting engine in Lean4:

![Screenshot](screenshots/screenshot1.png)

## Run

### Unix (Linux, Mac)

```bash
# Install elan if this is your first time using Lean
curl https://elan.lean-lang.org/elan-init.sh -sSf | sh

# Clone project
git clone --recursive https://github.com/oOo0oOo/LeanDoomed.git
cd LeanDoomed

# Run the "game". The initial run will take a few minutes to compile everything.
lake exe LeanDoomed
```

### Windows (MSYS2 or WSL)

On Windows, use MSYS2 or WSL!

**IMPORTANT**: FOR MSYS2, MAKE SURE YOU ARE USING THE "CLANG" SHELL TO RUN EVERYTHING!

For more information on MSYS2, see: https://github.com/leanprover/lean4/blob/master/doc/make/msys2.md

Next, follow the instructions for Unix above.

## License & Attribution

MIT

Wall texture by [FacadeGaikan](https://opengameart.org/node/31075), licensed under CC0.