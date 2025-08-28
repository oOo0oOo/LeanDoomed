import Lake
open System Lake DSL

package LeanDoomed

input_file sdl.c where
  path := "c" / "sdl.c"
  text := true

target sdl.o pkg : FilePath := do
  let srcJob ← sdl.c.fetch
  let oFile := pkg.buildDir / "c" / "sdl.o"
  let leanInclude := "/home/ooo/.elan/toolchains/leanprover--lean4---v4.22.0/include"
  buildO oFile srcJob #[] #["-fPIC", "-I/usr/include/SDL2", "-D_REENTRANT", s!"-I{leanInclude}"] "cc"

target libleansdl pkg : FilePath := do
  let sdlO ← sdl.o.fetch
  let name := nameToStaticLib "leansdl"
  buildStaticLib (pkg.staticLibDir / name) #[sdlO]

lean_lib SDL where
  moreLinkObjs := #[libleansdl]
  moreLinkArgs := #["-lSDL2", "-lSDL2_image"]

lean_lib Engine

@[default_target]
lean_exe LeanDoomed where
  root := `Main
  moreLinkArgs := #["/usr/lib/x86_64-linux-gnu/libSDL2.so", "/usr/lib/x86_64-linux-gnu/libSDL2_image.so"]
