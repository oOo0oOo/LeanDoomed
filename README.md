# Lean SDL3 Bindings Example

Playing around with SDL3 bindings in Lean4 to learn about the FFI.

Simple real-time Doom-style raycasting engine in Lean4:

![Screenshot](screenshots/screenshot1.png)

## Run

This is just an experiment and the build is currently specific to Linux only

make sure you run the build script first to build all the dependencies to get this to work

```bash
chmod +x ./build_sdl_and_friends.sh
sudo ./build_sdl_and_friends.sh
```

Then you can run the game proper

```bash
lake exe LeanDoomed
```

## License

MIT