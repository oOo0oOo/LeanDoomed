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

structure RenderContext where
  renderer : SDL.Renderer
  texture : Option SDL.Texture

structure EngineState where
  deltaTime : Float
  lastTime : UInt32
  running : Bool
  camera : Camera
  gameMap : Map

def SCREEN_WIDTH : Int32 := 1280
def SCREEN_HEIGHT : Int32 := 720
def FOV : Float := 1.047 -- ~60 degrees in radians
def TEXTURE_SIZE : Float := 64.0

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
  | .W => SDL.SCANCODE_W | .A => SDL.SCANCODE_A | .S => SDL.SCANCODE_S
  | .D => SDL.SCANCODE_D | .Left => SDL.SCANCODE_LEFT | .Right => SDL.SCANCODE_RIGHT
  | .Space => SDL.SCANCODE_SPACE | .Escape => SDL.SCANCODE_ESCAPE

def isKeyDown (key : Key) : IO Bool := SDL.isKeyPressed (keyToScancode key)

def isWall (mapp : Map) (x y : Float) : Bool :=
  if x < 0.0 || y < 0.0 then true else
    let mapX := x.floor.toUInt32.toNat
    let mapY := y.floor.toUInt32.toNat
    mapY >= mapp.size || mapX >= mapp[mapY]!.size || mapp[mapY]![mapX]! == 1

def castRay (map : Map) (startX startY angle : Float): Float × Float := Id.run do
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

  let distance := if side == 0
    then (mapX - startX + (1.0 - Float.ofInt stepX) / 2.0) / rayDirX
    else (mapY - startY + (1.0 - Float.ofInt stepY) / 2.0) / rayDirY

  let wallX := if side == 0
    then startY + distance * rayDirY
    else startX + distance * rayDirX

  let texX := (wallX - wallX.floor) * TEXTURE_SIZE
  (distance, texX)

def checkCollision (map : Map) (x y : Float) (radius : Float := 0.3) : Bool :=
  let corners := #[
    (x - radius, y - radius), (x + radius, y - radius),
    (x - radius, y + radius), (x + radius, y + radius)
  ]
  corners.any (fun (cx, cy) => isWall map cx cy)

def updateCamera (camera : Camera) (deltaTime : Float) : IO Camera := do
  let moveSpeed := camera.speed * deltaTime
  let mut newX := camera.x
  let mut newY := camera.y
  let mut newAngle := camera.angle

  if ← isKeyDown .W then
    let testX := camera.x + Float.cos camera.angle * moveSpeed
    let testY := camera.y + Float.sin camera.angle * moveSpeed
    if !checkCollision sampleMap testX camera.y then newX := testX
    if !checkCollision sampleMap camera.x testY then newY := testY

  if ← isKeyDown .S then
    let testX := camera.x - Float.cos camera.angle * moveSpeed
    let testY := camera.y - Float.sin camera.angle * moveSpeed
    if !checkCollision sampleMap testX camera.y then newX := testX
    if !checkCollision sampleMap camera.x testY then newY := testY

  if ← isKeyDown .A then newAngle := newAngle - camera.turnSpeed * deltaTime
  if ← isKeyDown .D then newAngle := newAngle + camera.turnSpeed * deltaTime

  pure { camera with x := newX, y := newY, angle := newAngle }

def setColor (ctx : RenderContext) (color : Color) : IO Unit :=
  SDL.setDrawColor ctx.renderer color.r color.g color.b color.a

def fillRect (ctx : RenderContext) (x y w h : Int32) : IO Unit :=
  SDL.fillRect ctx.renderer x y w h

def renderScene (ctx : RenderContext) (state : EngineState) : IO Unit := do
  setColor ctx { r := 135, g := 206, b := 235 }
  SDL.clear ctx.renderer

  let rayStep := FOV / SCREEN_WIDTH.toFloat
  for column in [0:SCREEN_WIDTH.toNatClampNeg] do
    let rayAngle := state.camera.angle - FOV/2 + column.toFloat * rayStep
    let (distance, texX) := castRay state.gameMap state.camera.x state.camera.y rayAngle
    let wallHeight := (SCREEN_HEIGHT.toFloat / max 0.1 distance) * 1.5

    let wallStart := (SCREEN_HEIGHT.toFloat - wallHeight) / 2
    let visibleStart := max 0 wallStart
    let visibleEnd := min SCREEN_HEIGHT.toFloat (wallStart + wallHeight)

    let wallStartInt := visibleStart.toInt32
    let wallEndInt := visibleEnd.toInt32
    let wallHeightInt := wallEndInt - wallStartInt

    if wallHeightInt > 0 then
      let (texYStart, texYEnd) :=
        if wallHeight <= SCREEN_HEIGHT.toFloat then (0, TEXTURE_SIZE.toInt32)
        else
          let zoom := wallHeight / SCREEN_HEIGHT.toFloat
          let visible := TEXTURE_SIZE / zoom
          let start := 0.5 + (TEXTURE_SIZE - visible) / 2
          (start.toInt32, (start + visible).toInt32)

      match ctx.texture with
      | some tex => SDL.renderTextureColumn ctx.renderer tex column.toInt32 wallStartInt wallHeightInt texX.toInt32 texYStart texYEnd
      | none => pure ()

    let shade := max 20 (50 - distance * 5).toUInt8
    setColor ctx { r := shade, g := shade + 30, b := shade }
    fillRect ctx column.toInt32 wallEndInt 1 (SCREEN_HEIGHT - wallEndInt)

private def updateEngineState (engineState : IO.Ref EngineState) : IO Unit := do
  let state ← engineState.get
  let currentTime ← SDL.getTicks
  let deltaTime := (currentTime - state.lastTime).toFloat / 1000.0
  let newCamera ← updateCamera state.camera deltaTime
  engineState.set { state with deltaTime, lastTime := currentTime, camera := newCamera }

partial def gameLoop (ctx : RenderContext) (engineState : IO.Ref EngineState) : IO Unit := do
  updateEngineState engineState

  let eventType ← SDL.pollEvent
  if eventType == SDL.EVENT_QUIT || (← isKeyDown .Escape) then
    engineState.modify (fun s => { s with running := false })

  let state ← engineState.get
  if state.running then
    renderScene ctx state
    SDL.present ctx.renderer
    gameLoop ctx engineState

partial def run : IO Unit := do
  unless (← SDL.init SDL.INIT_VIDEO) do
    IO.println "Failed to initialize SDL"
    return

  let some window ← SDL.createWindow "LeanDoomed" SCREEN_WIDTH SCREEN_HEIGHT
    | do IO.println "Failed to create window"; SDL.quit; return

  let some renderer ← SDL.createRenderer window
    | do IO.println "Failed to create renderer"; SDL.destroyWindow window; SDL.quit; return

  let texture ← SDL.loadTexture renderer "wall.png"
  if texture.isNone then
    IO.println "Failed to load texture, using solid colors"

  let ctx : RenderContext := { renderer, texture }

  let initialState : EngineState := {
    deltaTime := 0.0, lastTime := 0, running := true,
    camera := { x := 1.5, y := 1.5, angle := 0.0 },
    gameMap := sampleMap
  }

  let engineState ← IO.mkRef initialState
  IO.println "Use WASD to move, A/D to turn, ESC to quit"
  gameLoop ctx engineState

  -- Cleanup
  if let some tex := texture then
    SDL.destroyTexture tex
  SDL.destroyRenderer renderer
  SDL.destroyWindow window
  SDL.quit

def EngineState.setRunning (state : EngineState) (running : Bool) : EngineState :=
  { state with running }

end Engine
