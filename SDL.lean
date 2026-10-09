namespace SDL

-- Opaque types for SDL resources (type-safe handles)
private opaque WindowPointed : NonemptyType
def Window : Type := WindowPointed.type
instance : Nonempty Window := WindowPointed.property

private opaque RendererPointed : NonemptyType
def Renderer : Type := RendererPointed.type
instance : Nonempty Renderer := RendererPointed.property

private opaque TexturePointed : NonemptyType
def Texture : Type := TexturePointed.type
instance : Nonempty Texture := TexturePointed.property

-- SDL Constants
def INIT_VIDEO : UInt32 := 0x00000020
def EVENT_QUIT : UInt32 := 0x100

-- Scancodes
def SCANCODE_W : UInt32 := 26
def SCANCODE_A : UInt32 := 4
def SCANCODE_S : UInt32 := 22
def SCANCODE_D : UInt32 := 7
def SCANCODE_LEFT : UInt32 := 80
def SCANCODE_RIGHT : UInt32 := 79
def SCANCODE_SPACE : UInt32 := 44
def SCANCODE_ESCAPE : UInt32 := 41

-- Initialization
@[extern "sdl_init"]
opaque init (flags : UInt32) : IO Bool

@[extern "sdl_quit"]
opaque quit : IO Unit

-- Window management
@[extern "sdl_create_window"]
opaque createWindow (title : @& String) (w h : Int32) : IO (Option Window)

@[extern "sdl_destroy_window"]
opaque destroyWindow (window : @& Window) : IO Unit

-- Renderer management
@[extern "sdl_create_renderer"]
opaque createRenderer (window : @& Window) : IO (Option Renderer)

@[extern "sdl_destroy_renderer"]
opaque destroyRenderer (renderer : @& Renderer) : IO Unit

-- Drawing operations
@[extern "sdl_set_draw_color"]
opaque setDrawColor (renderer : @& Renderer) (r g b a : UInt8) : IO Unit

@[extern "sdl_clear"]
opaque clear (renderer : @& Renderer) : IO Unit

@[extern "sdl_present"]
opaque present (renderer : @& Renderer) : IO Unit

@[extern "sdl_fill_rect"]
opaque fillRect (renderer : @& Renderer) (x y w h : Int32) : IO Unit

-- Texture operations
@[extern "sdl_load_texture"]
opaque loadTexture (renderer : @& Renderer) (path : @& String) : IO (Option Texture)

@[extern "sdl_destroy_texture"]
opaque destroyTexture (texture : @& Texture) : IO Unit

@[extern "sdl_render_texture_column"]
opaque renderTextureColumn (renderer : @& Renderer) (texture : @& Texture)
  (dstX dstY dstH srcX srcYStart srcYEnd : Int32) : IO Unit

-- Scalar field order is checked against generated C in tests/check_abi.py.
structure DrawColumn where
  x : Int32
  y : Int32
  height : Int32
  texX : Int32
  texYStart : Int32
  texYEnd : Int32
  shade : UInt8

@[extern "sdl_render_columns"]
opaque renderColumns (renderer : @& Renderer) (texture : @& Option Texture)
  (columns : @& Array DrawColumn) (screenHeight : Int32) : IO Unit

@[extern "sdl_pixel_hash"]
opaque pixelHash (renderer : @& Renderer) : IO UInt64

-- Input and timing
@[extern "sdl_poll_event"]
opaque pollEvent : IO UInt32

@[extern "sdl_get_ticks"]
opaque getTicks : IO UInt32

@[extern "sdl_is_key_pressed"]
opaque isKeyPressed (scancode : UInt32) : IO Bool

@[extern "sdl_delay"]
opaque delay (ms : UInt32) : IO Unit

end SDL
