# Lean SDL3 Bindings Example

Playing around with SDL3 bindings in Lean4 to learn about the FFI.

Simple real-time Doom-style raycasting engine in Lean4:

![Screenshot](screenshots/screenshot1.png)

## Run

### Unix (Linux, Mac)

```bash
# Install elan if this is your first time using Lean
curl https://elan.lean-lang.org/elan-init.sh -sSf | sh

# Clone project and submodules (SDL3 etc)
git clone --recurse-submodules https://github.com/ValorZard/LeanDoomed.git
cd LeanDoomed

# Build dependencies
chmod +x ./build_sdl_and_friends.sh
sudo ./build_sdl_and_friends.sh

# Run the "game"
lake exe LeanDoomed
```

### Windows (MSYS2 or WSL)

On Windows, use MSYS2 or WSL!

**IMPORTANT**: FOR MSYS2, MAKE SURE YOU ARE USING THE "CLANG" SHELL TO RUN EVERYTHING!

For more information on MSYS2, see: https://github.com/leanprover/lean4/blob/master/doc/make/msys2.md

Next, follow the instructions for Unix above.

## License

MIT
