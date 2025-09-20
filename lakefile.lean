import Lake
open System Lake DSL

package LeanDoomed

def sdlGitRepo : String := "https://github.com/libsdl-org/SDL.git"
def sdlRepoDir : String := "vendor/SDL"

def sdlImageGitRepo : String := "https://github.com/libsdl-org/SDL_image.git"
def sdlImageRepoDir : String := "vendor/SDL_image"

-- clone from a stable branch to avoid breakages
def sdlBranch : String := "release-3.2.x"

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
-- Helper function to run command and handle errors
-- Clone the repos if they don't exist
  let sdlExists ← System.FilePath.pathExists sdlRepoDir
  if !sdlExists then
    IO.println "Cloning SDL"
    let sdlClone ← IO.Process.output { cmd := "git", args := #["clone", "-b", sdlBranch, "--single-branch", "--depth", "1", "--recursive", sdlGitRepo, sdlRepoDir] }
    if sdlClone.exitCode != 0 then
      IO.println s!"Error cloning SDL: {sdlClone.stderr}"
    else
      IO.println "SDL cloned successfully"
      IO.println sdlClone.stdout

  let sdlImageExists ← System.FilePath.pathExists sdlImageRepoDir
  if !sdlImageExists then
    IO.println "Cloning SDL_image"
    let sdlImageClone ← IO.Process.output { cmd := "git", args := #["clone", "-b", sdlBranch, "--single-branch", "--depth", "1", "--recursive", sdlImageGitRepo, sdlImageRepoDir] }
    if sdlImageClone.exitCode != 0 then
      IO.println s!"Error cloning SDL_image: {sdlImageClone.stderr}"
    else
      IO.println "SDL_image cloned successfully"
      IO.println sdlImageClone.stdout

-- Build the repos with cmake
-- SDL itself needs to be built before SDL_image, as the latter depends on the former
-- We also need to make sure we are using a system provided C compiler, as the one that comes with Lean is missing important headers
  IO.println "Building SDL"
-- Create build directory if it doesn't exist
  let sdlBuildDirExists ← System.FilePath.pathExists (sdlRepoDir ++ "/build")
  if !sdlBuildDirExists then
    let configureSdlBuild ← IO.Process.output { cmd := "cmake", args := #["-S", sdlRepoDir, "-B", sdlRepoDir ++ "/build", "-DBUILD_SHARED_LIBS=ON", "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_C_COMPILER=cc"] }
    if configureSdlBuild.exitCode != 0 then
      IO.println s!"Error configuring SDL: {configureSdlBuild.stderr}"
    else
      IO.println "SDL configured successfully"
      IO.println configureSdlBuild.stdout
  else
    IO.println "SDL build directory already exists, skipping configuration step"
-- now actually build SDL once we've configured it
  let buildSdl ← IO.Process.output { cmd := "cmake", args :=  #["--build", sdlRepoDir ++ "/build", "--config", "Release",] }
  if buildSdl.exitCode != 0 then
    IO.println s!"Error building SDL: {buildSdl.exitCode}"
    IO.println buildSdl.stderr
  else
    IO.println "SDL built successfully"
    IO.println buildSdl.stdout
-- Build SDL_Image
  IO.println "Building SDL_image"
-- Create SDL_Image build directory if it doesn't exist
  let sdlImageBuildDirExists ← System.FilePath.pathExists (sdlImageRepoDir ++ "/build")
  if !sdlImageBuildDirExists then
    let currentDir ← IO.currentDir
    let sdlConfigPath := currentDir / sdlRepoDir / "build"
    let configureSdlImageBuild ← IO.Process.output { cmd := "cmake", args :=  #["-S", sdlImageRepoDir, "-B", sdlImageRepoDir ++ "/build", s!"-DSDL3_DIR={sdlConfigPath}", "-DBUILD_SHARED_LIBS=ON", "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_C_COMPILER=cc"] }
    if configureSdlImageBuild.exitCode != 0 then
      IO.println s!"Error configuring SDL_image: {configureSdlImageBuild.stderr}"
    else
      IO.println "SDL_image configured successfully"
      IO.println configureSdlImageBuild.stdout
  else
    IO.println "SDL_image build directory already exists, skipping configuration step"
-- now actually build SDL_image once we've configured it
  let buildSdlImage ← IO.Process.output { cmd := "cmake", args := #["--build", sdlImageRepoDir ++ "/build", "--config", "Release"] }
  if buildSdlImage.exitCode != 0 then
    IO.println s!"Error building SDL_image: {buildSdlImage.stderr}"
  else
    IO.println "SDL_image built successfully"
    IO.println buildSdlImage.stdout

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
