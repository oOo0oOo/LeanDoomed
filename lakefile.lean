import Lake
open System Lake DSL

package LeanDoomed

-- we can clone directly from main, I'm sure this is fine :)
def sdlGitRepo : String := "https://github.com/libsdl-org/SDL.git"
def sdlRepoDir : FilePath := "vendor/SDL"

def sdlImageGitRepo : String := "https://github.com/libsdl-org/SDL_image.git"
def sdlImageRepoDir : FilePath := "vendor/SDL_image"

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
  let _ ← IO.Process.run { cmd := "git", args := #["clone", "--depth", "1", "--recursive", sdlGitRepo, "vendor/SDL"] }
  let _ ← IO.Process.run { cmd := "git", args := #["clone", "--depth", "1", "--recursive", sdlImageGitRepo, "vendor/SDL_image"] }
  let sdlO ← sdl.o.fetch
  let name := nameToStaticLib "leansdl"
  -- manually copy the DLLs we need to .lake/build/bin/ for the game to work
  IO.FS.createDirAll ".lake/build/bin/"
  let dstDir := ".lake/build/bin/"
  let sdlBinariesDir : FilePath := "vendor/SDL/build/"
  for entry in (← sdlBinariesDir.readDir) do
    if entry.path.extension != none then
      copyFile entry.path (dstDir / entry.path.fileName.get!)
  let sdlImageBinariesDir : FilePath := "vendor/SDL_image/build/"
  for entry in (← sdlImageBinariesDir.readDir) do
    if entry.path.extension != none then
      copyFile entry.path (dstDir / entry.path.fileName.get!)
  if Platform.isWindows then
    -- binaries for Lean/Lake itself for the executable to run standalone
    let lakeBinariesDir := (← IO.appPath).parent.get!
    println! "Copying Lake DLLs from {lakeBinariesDir}"

    for entry in (← lakeBinariesDir.readDir) do
      if entry.path.extension == some "dll" then
       copyFile entry.path (".lake/build/bin/" / entry.path.fileName.get!)
  else
  -- binaries for Lean/Lake itself, like libgmp are on a different place on Linux
    let lakeBinariesDir := (← IO.appPath).parent.get!.parent.get! / "lib"
    println! "Copying Lake binaries from {lakeBinariesDir}"

    for entry in (← lakeBinariesDir.readDir) do
      if entry.path.extension != none then
       copyFile entry.path (".lake/build/bin/" / entry.path.fileName.get!)

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
    #["vendor/SDL/build/SDL3.dll", "vendor/SDL_image/build/SDL3_image.dll"]
  else
    #["vendor/SDL/build/libSDL3.so", "vendor/SDL_image/build/libSDL3_image.so", "-Wl,--allow-shlib-undefined", "-Wl,-rpath=$ORIGIN", "-Wl,-rpath=$ORIGIN"]
