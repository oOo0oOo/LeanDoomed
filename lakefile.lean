import Lake
open System Lake DSL

package LeanDoomed where
  testDriver := "doomed_tests"

def sdlVersion := "release-3.4.18"
def sdlImageVersion := "release-3.4.8"

private def checked (cmd : String) (args : Array String) : IO Unit := do
  let output ← IO.Process.output { cmd, args }
  if output.exitCode != 0 then
    throw <| IO.userError s!"{cmd} {args} failed ({output.exitCode}):\n{output.stdout}\n{output.stderr}"

private def ensureVendor (name version : String) : IO Unit := do
  let dir := s!"vendor/{name}"
  if !(← FilePath.pathExists dir) then
    checked "git" #["clone", "--branch", version, "--single-branch", "--depth", "1", "--recursive",
      s!"https://github.com/libsdl-org/{name}.git", dir]
  let head ← IO.Process.output { cmd := "git", args := #["-C", dir, "rev-parse", "HEAD"] }
  let pinned ← IO.Process.output { cmd := "git", args := #["-C", dir, "rev-parse", version ++ "^{commit}"] }
  if head.exitCode != 0 || pinned.exitCode != 0 || head.stdout != pinned.stdout then
    throw <| IO.userError s!"{dir} must be at {version}. Preserve any changes and move the old checkout aside before rebuilding."

private def configure (source build : FilePath) (extra : Array String := #[]) : IO Unit := do
  let root := ((← IO.currentDir) / source).normalize.toString
  let marker := build / ".source-root"
  let previous ← try IO.FS.readFile marker catch _ => pure ""
  if previous != "" && previous != root then
    -- CMake caches absolute source paths. Discard only generated configuration on relocation.
    let cache := build / "CMakeCache.txt"
    if ← cache.pathExists then IO.FS.removeFile cache
    let files := build / "CMakeFiles"
    if ← files.pathExists then IO.FS.removeDirAll files
  checked "cmake" <| #["-S", source.toString, "-B", build.toString,
    "-DBUILD_SHARED_LIBS=ON", "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_C_COMPILER=cc"] ++ extra
  IO.FS.writeFile marker root

input_file sdl.c where
  path := "c" / "sdl.c"
  text := true

input_file sdl_abi.h where
  path := "c" / "sdl_abi.h"
  text := true

target libleansdl pkg : FilePath := do
  ensureVendor "SDL" sdlVersion
  ensureVendor "SDL_image" sdlImageVersion
  let sdlBuild := pkg.buildDir / "vendor" / "SDL"
  let imageBuild := pkg.buildDir / "vendor" / "SDL_image"
  configure "vendor/SDL" sdlBuild #["-DSDL_TESTS=OFF", "-DSDL_EXAMPLES=OFF"]
  let jobs := (← IO.getEnv "CMAKE_BUILD_PARALLEL_LEVEL").getD "4"
  checked "cmake" #["--build", sdlBuild.toString, "--config", "Release", "--parallel", jobs]
  configure "vendor/SDL_image" imageBuild #[s!"-DSDL3_DIR={((← IO.currentDir) / sdlBuild).normalize}",
    "-DSDLIMAGE_SAMPLES=OFF", "-DSDLIMAGE_TESTS=OFF"]
  checked "cmake" #["--build", imageBuild.toString, "--config", "Release", "--parallel", jobs]

  let src ← sdl.c.fetch
  let header ← sdl_abi.h.fetch
  let leanInclude := (← getLeanIncludeDir).toString
  let object ← buildO (pkg.buildDir / "c" / "sdl.o") src #["-include", "c/sdl_abi.h"]
    #["-fPIC", "-Wall", "-Wextra", "-Werror", "-Ivendor/SDL/include", "-Ivendor/SDL_image/include", s!"-I{leanInclude}"] "cc" (do let _ ← header.await; pure header.getTrace)
  IO.FS.createDirAll pkg.binDir
  let names := if Platform.isWindows then #["SDL3.dll", "SDL3_image.dll"]
    else if Platform.isOSX then #["libSDL3.0.dylib", "libSDL3_image.0.dylib"]
    else #["libSDL3.so.0", "libSDL3_image.so.0"]
  for (dir, name) in #[sdlBuild, imageBuild].zip names do
    copyFile (dir / name) (pkg.binDir / name)
  if Platform.isWindows then
    for entry in (← (← IO.appPath).parent.get!.readDir) do
      if entry.path.extension == some "dll" then copyFile entry.path (pkg.binDir / entry.path.fileName.get!)
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "leansdl") #[object]

lean_lib SDL where
  moreLinkObjs := #[libleansdl]

lean_lib Engine

def nativeLinkArgs : Array String :=
  if Platform.isWindows then #[".lake/build/vendor/SDL/SDL3.dll", ".lake/build/vendor/SDL_image/SDL3_image.dll"]
  else if Platform.isOSX then #[".lake/build/vendor/SDL/libSDL3.dylib", ".lake/build/vendor/SDL_image/libSDL3_image.dylib", "-Wl,-rpath,@executable_path"]
  else #[".lake/build/vendor/SDL/libSDL3.so", ".lake/build/vendor/SDL_image/libSDL3_image.so", "-Wl,--allow-shlib-undefined", "-Wl,-rpath,$ORIGIN"]

@[default_target]
lean_exe LeanDoomed where
  root := `Main
  moreLinkArgs := nativeLinkArgs

lean_exe doomed_tests where
  root := `Tests
  moreLinkArgs := nativeLinkArgs
