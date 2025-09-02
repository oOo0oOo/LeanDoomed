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
  let sdlInclude := "vendor/SDL/include/"
  let sdlImageInclude := "vendor/SDL_image/include/"
  buildO oFile srcJob #[] #["-fPIC", s!"-I{sdlInclude}", s!"-I{sdlImageInclude}", "-D_REENTRANT", s!"-I{leanInclude}"] "cc"

target libleansdl pkg : FilePath := do
  let sdlO ← sdl.o.fetch
  let name := nameToStaticLib "leansdl"
  -- manually copy the DLLs we need to .lake/build/bin/ for the game to work
  if Platform.isWindows then
    copyFile "vendor/SDL/build/SDL3.dll" ".lake/build/bin/SDL3.DLL"
    copyFile "vendor/SDL_image/build/SDL3_image.dll" ".lake/build/bin/SDL3_image.DLL"
  buildStaticLib (pkg.staticLibDir / name) #[sdlO]

lean_lib SDL where
  moreLinkObjs := #[libleansdl]
  moreLinkArgs := #["-lSDL3", "-lSDL3_image"]

lean_lib Engine

@[default_target]
lean_exe LeanDoomed where
  root := `Main
  -- we have to add the rpath to tell the compiler where all of the libraries are
  moreLinkArgs := if Platform.isWindows then
    #[]
  else
    #["vendor/SDL/build/libSDL3.so", "vendor/SDL_image/build/libSDL3_image.so", "-Wl,--allow-shlib-undefined", "-Wl,-rpath=vendor/SDL/build/", "-Wl,-rpath=vendor/SDL_image/build/"]
