import Lake
open System Lake DSL

package LeanDoomed

input_file sdl.c where
  path := "c" / "sdl.c"
  text := true

target sdl.o pkg : FilePath := do
  let srcJob ← sdl.c.fetch
  let oFile := pkg.buildDir / "c" / "sdl.o"
  let leanInclude := (<- getLeanIncludeDir).toString
  let sdlInclude := "SDL/include/"
  let sdlImageInclude := "SDL_image/include/"
  buildO oFile srcJob #[] #["-fPIC", s!"-I{sdlInclude}", s!"-I{sdlImageInclude}", "-D_REENTRANT", s!"-I{leanInclude}", s!"-I{sdlInclude}", s!"-I{sdlImageInclude}"] "cc"

target libleansdl pkg : FilePath := do
  let sdlO ← sdl.o.fetch
  let name := nameToStaticLib "leansdl"
  buildStaticLib (pkg.staticLibDir / name) #[sdlO]

lean_lib SDL where
  moreLinkObjs := #[libleansdl]
  moreLinkArgs := #["-lSDL3", "-lSDL3_image"]

lean_lib Engine

@[default_target]
lean_exe LeanDoomed where
  root := `Main
  moreLinkArgs := #["SDL/build/libSDL3.so", "SDL_image/build/libSDL3_image.so", "-Wl,--allow-shlib-undefined", "-Wl,-rpath=SDL/build/", "-Wl,-rpath=SDL_image/build/"]
