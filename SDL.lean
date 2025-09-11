namespace SDL

def SDL_INIT_VIDEO : UInt32 := 0x00000020
def SDL_WINDOW_SHOWN : UInt32 := 0x00000004
def SDL_RENDERER_ACCELERATED : UInt32 := 0x00000002
def SDL_QUIT : UInt32 := 0x100

def SDL_SCANCODE_W : UInt32 := 26
def SDL_SCANCODE_A : UInt32 := 4
def SDL_SCANCODE_S : UInt32 := 22
def SDL_SCANCODE_D : UInt32 := 7
def SDL_SCANCODE_LEFT : UInt32 := 80
def SDL_SCANCODE_RIGHT : UInt32 := 79
def SDL_SCANCODE_SPACE : UInt32 := 44
def SDL_SCANCODE_ESCAPE : UInt32 := 41

@[extern "sdl_init"]
opaque init : UInt32 → IO UInt32

@[extern "sdl_quit"]
opaque quit : IO Unit

@[extern "sdl_create_window"]
opaque createWindow : String → Int32 → Int32 → UInt32 → IO UInt32

@[extern "sdl_create_renderer"]
opaque createRenderer : Unit → IO UInt32

@[extern "sdl_set_render_draw_color"]
opaque setRenderDrawColor : UInt8 → UInt8 → UInt8 → UInt8 → IO Int32

@[extern "sdl_render_clear"]
opaque renderClear : IO Int32

@[extern "sdl_render_present"]
opaque renderPresent : IO Unit

@[extern "sdl_render_fill_rect"]
opaque renderFillRect : Int32 → Int32 → Int32 → Int32 → IO Int32

@[extern "sdl_delay"]
opaque delay : UInt32 → IO Unit

@[extern "sdl_poll_event"]
opaque pollEvent : IO UInt32

@[extern "sdl_get_ticks"]
opaque getTicks : IO UInt32

@[extern "sdl_get_key_state"]
opaque getKeyState : UInt32 → IO Bool

@[extern "sdl_load_texture"]
opaque loadTexture : String → IO UInt32

@[extern "sdl_render_texture_column"]
opaque renderTextureColumn : Int32 → Int32 → Int32 → Int32 → Int32 → Int32 → IO Int32

end SDL
