import SDL

namespace Engine

structure Color where
  r : UInt8
  g : UInt8
  b : UInt8
  a : UInt8 := 255

structure Camera where
  x : Float
  y : Float
  angle : Float
  speed : Float := 3.0
  turnSpeed : Float := 2.0

abbrev Map := Array (Array UInt8)

structure EngineState where
  deltaTime : Float
  lastTime : UInt32
  running : Bool
  camera : Camera
  gameMap : Map

def SCREEN_WIDTH : Int32 := 1280
def SCREEN_HEIGHT : Int32 := 720
def FOV : Float := 1.047 -- ~60 degrees in radians

def sampleMap : Map := #[
  #[1,1,1,1,1,1,1,1,1,1],
  #[1,0,0,0,0,0,0,0,0,1],
  #[1,0,1,0,0,0,0,1,0,1],
  #[1,0,0,0,0,0,0,0,0,1],
  #[1,0,0,0,1,1,0,0,0,1],
  #[1,0,0,0,1,1,0,0,0,1],
  #[1,0,0,0,0,0,0,0,0,1],
  #[1,0,1,0,0,0,0,1,0,1],
  #[1,0,0,0,0,0,0,0,0,1],
  #[1,1,1,1,1,1,1,1,1,1]
]

inductive Key where
  | W | A | S | D | Left | Right | Space | Escape

def keyToScancode : Key → UInt32
  | .W => SDL.SDL_SCANCODE_W | .A => SDL.SDL_SCANCODE_A | .S => SDL.SDL_SCANCODE_S
  | .D => SDL.SDL_SCANCODE_D | .Left => SDL.SDL_SCANCODE_LEFT | .Right => SDL.SDL_SCANCODE_RIGHT
  | .Space => SDL.SDL_SCANCODE_SPACE | .Escape => SDL.SDL_SCANCODE_ESCAPE

def isKeyDown (key : Key) : IO Bool := SDL.getKeyState (keyToScancode key)

def isWall (mapp : Map) (x y : Float) : Bool :=
  if x < 0.0 || y < 0.0 then true else
    let mapX := x.floor.toUInt32.toNat
    let mapY := y.floor.toUInt32.toNat
    mapY >= mapp.size || mapX >= mapp[mapY]!.size || mapp[mapY]![mapX]! == 1

def castRay (map : Map) (startX startY angle : Float) : Float := Id.run do
  let rayDirX := Float.cos angle
  let rayDirY := Float.sin angle
  let mut mapX := startX.floor
  let mut mapY := startY.floor

  let deltaDistX := if rayDirX == 0.0 then 1e30 else Float.abs (1.0 / rayDirX)
  let deltaDistY := if rayDirY == 0.0 then 1e30 else Float.abs (1.0 / rayDirY)

  let stepX := if rayDirX < 0.0 then -1 else 1
  let mut sideDistX := if rayDirX < 0.0 then (startX - mapX) * deltaDistX else (mapX + 1.0 - startX) * deltaDistX
  let stepY := if rayDirY < 0.0 then -1 else 1
  let mut sideDistY := if rayDirY < 0.0 then (startY - mapY) * deltaDistY else (mapY + 1.0 - startY) * deltaDistY

  let mut hit := false
  let mut side := 0

  for _ in [0:25] do
    if hit then break
    if sideDistX < sideDistY then
      sideDistX := sideDistX + deltaDistX
      mapX := mapX + Float.ofInt stepX
      side := 0
    else
      sideDistY := sideDistY + deltaDistY
      mapY := mapY + Float.ofInt stepY
      side := 1

    hit := isWall map mapX mapY

  if side == 0
  then (mapX - startX + (1.0 - Float.ofInt stepX) / 2.0) / rayDirX
  else (mapY - startY + (1.0 - Float.ofInt stepY) / 2.0) / rayDirY

def updateCamera (camera : Camera) (deltaTime : Float) : IO Camera := do
  let moveSpeed := camera.speed * deltaTime
  let mut newX := camera.x
  let mut newY := camera.y
  let mut newAngle := camera.angle

  if ← isKeyDown .W then
    newX := newX + Float.cos camera.angle * moveSpeed
    newY := newY + Float.sin camera.angle * moveSpeed
  if ← isKeyDown .S then
    newX := newX - Float.cos camera.angle * moveSpeed
    newY := newY - Float.sin camera.angle * moveSpeed
  if ← isKeyDown .A then newAngle := newAngle - camera.turnSpeed * deltaTime
  if ← isKeyDown .D then newAngle := newAngle + camera.turnSpeed * deltaTime

  pure { camera with x := newX, y := newY, angle := newAngle }

def setColor (color : Color) : IO Unit :=
  SDL.setRenderDrawColor color.r color.g color.b color.a *> pure ()

def fillRect (x y w h : Int32) : IO Unit :=
  SDL.renderFillRect x y w h *> pure ()

def renderScene (state : EngineState) : IO Unit := do
  setColor { r := 87, g := 127, b := 137 }
  let _ ← SDL.renderClear

  let camera := state.camera
  let rayAngleStep := FOV / SCREEN_WIDTH.toFloat

  for column in [0:SCREEN_WIDTH.toNatClampNeg] do
    let rayAngle := camera.angle - FOV/2 + column.toFloat * rayAngleStep
    let distance := max 0.1 (castRay state.gameMap camera.x camera.y rayAngle)
    let wallHeight := (SCREEN_HEIGHT.toFloat / distance) * 1.5

    let wallStart := max 0 ((SCREEN_HEIGHT.toFloat - wallHeight) / 2).toInt32
    let wallEnd := min (SCREEN_HEIGHT - 1) (wallStart + wallHeight.toInt32)
    let xPos := column.toInt32

    if wallStart > 0 then
      setColor { r := 135, g := 206, b := 235 }
      fillRect xPos 0 1 wallStart

    if wallStart < wallEnd then
      let lightIntensity := max 0.3 (1.0 - distance / 8.0)
      let col := (200.0 * lightIntensity).toUInt8
      setColor { r := col, g := col, b := col + 20 }
      fillRect xPos wallStart 1 (wallEnd - wallStart)

    if wallEnd < SCREEN_HEIGHT - 1 then
      let floorShade := max 20 (60 - distance * 5).toUInt8
      setColor { r := floorShade, g := floorShade + 30, b := floorShade }
      fillRect xPos wallEnd 1 (SCREEN_HEIGHT - 1 - wallEnd)

private def updateEngineState (engineState : IO.Ref EngineState) : IO Unit := do
  let state ← engineState.get
  let currentTime ← SDL.getTicks
  let deltaTime := (currentTime - state.lastTime).toFloat / 1000.0
  let newCamera ← updateCamera state.camera deltaTime
  engineState.set { state with deltaTime, lastTime := currentTime, camera := newCamera }

partial def gameLoop (engineState : IO.Ref EngineState) : IO Unit := do
  updateEngineState engineState

  let eventType ← SDL.pollEvent
  if eventType == SDL.SDL_QUIT || (← isKeyDown .Escape) then
    engineState.modify (fun s => { s with running := false })

  let state ← engineState.get
  if state.running then
    renderScene state
    SDL.renderPresent
    gameLoop engineState

partial def run : IO Unit := do
  unless (← SDL.init SDL.SDL_INIT_VIDEO) == 1 do
    IO.println "Failed to initialize SDL"
    return

  unless (← SDL.createWindow "LeanDoomed" SCREEN_WIDTH SCREEN_HEIGHT SDL.SDL_WINDOW_SHOWN) != 0 do
    IO.println "Failed to create window"
    SDL.quit
    return


  unless (← SDL.createRenderer ()) != 0 do
    IO.println "Failed to create renderer"
    SDL.quit
    return


  let initialState : EngineState := {
    deltaTime := 0.0, lastTime := 0, running := true,
    camera := { x := 1.5, y := 1.5, angle := 0.0 },
    gameMap := sampleMap
  }

  let engineState ← IO.mkRef initialState
  IO.println "Use WASD to move, A/D to turn, ESC to quit"
  gameLoop engineState
  SDL.quit

def EngineState.setRunning (state : EngineState) (running : Bool) : EngineState :=
  { state with running }

end Engine
