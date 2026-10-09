import Engine

open Engine

private def check (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw <| IO.userError message

private def state : EngineState := {
  deltaTime := 0, lastTime := 0, running := true,
  camera := { x := 1.5, y := 1.5, angle := 0 }, gameMap := sampleMap }

private def benchmark (label : String) (render : RenderContext → EngineState → IO Unit)
    (ctx : RenderContext) : IO Unit := do
  let start ← IO.monoMsNow
  for _ in [:100] do
    render ctx state
    SDL.present ctx.renderer
  IO.println s!"{label}, 100 frames: {(← IO.monoMsNow) - start} ms"

def main (args : List String) : IO Unit := do
  let abi ← IO.Process.output { cmd := "python3", args := #["tests/check_abi.py"] }
  check (abi.exitCode == 0) s!"ABI check failed: {abi.stdout}\n{abi.stderr}"
  IO.print abi.stdout
  check (isWall sampleMap (-1) 1) "Outside map is not a wall"
  check (!checkCollision sampleMap 1.5 1.5) "Initial camera collides"
  let (distance, _) := castRay sampleMap 1.5 1.5 0
  check (Float.abs (distance - 7.5) < 0.000001) "Ray distance changed"
  check (← SDL.init SDL.INIT_VIDEO) "SDL initialization failed"
  try
    let some window ← SDL.createWindow "LeanDoomed tests" SCREEN_WIDTH SCREEN_HEIGHT
      | throw <| IO.userError "Window creation failed"
    try
      let some renderer ← SDL.createRenderer window
        | throw <| IO.userError "Renderer creation failed"
      try
        check (!(← SDL.isKeyPressed 0xFFFFFFFF)) "Invalid scancode is not rejected"
        let some texture ← SDL.loadTexture renderer "wall.png"
          | throw <| IO.userError "Texture load failed"
        try
          for option in [some texture, none] do
            let ctx : RenderContext := { renderer, texture := option }
            for camera in [state.camera, { state.camera with x := 3.5, y := 3.5, angle := 1.2 }] do
              let sample := { state with camera }
              renderSceneLegacy ctx sample
              let before ← SDL.pixelHash renderer
              renderScene ctx sample
              check ((← SDL.pixelHash renderer) == before) "Batched rendering changed pixels"
            if args.contains "--benchmark" then
              IO.println (if option.isSome then "Textured rendering" else "Solid fallback")
              for repetition in [:5] do
                if repetition % 2 == 0 then
                  benchmark "legacy" renderSceneLegacy ctx
                  benchmark "batched" renderScene ctx
                else
                  benchmark "batched" renderScene ctx
                  benchmark "legacy" renderSceneLegacy ctx
          let ref ← IO.mkRef state
          gameLoop { renderer, texture := some texture } ref (some 3)
          SDL.delay 1
          let _ ← SDL.getTicks
          IO.println "Engine, FFI, texture/fallback pixel equality and bounded loop tests passed"
        finally SDL.destroyTexture texture
      finally SDL.destroyRenderer renderer
    finally SDL.destroyWindow window
  finally SDL.quit
