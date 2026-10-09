// Generated from SDL.lean by Lean 4.34.1; check with tests/check_abi.py.
#pragma once
#include <lean/lean.h>

lean_object* sdl_init(uint32_t);
lean_object* sdl_quit(void);
lean_object* sdl_create_window(lean_object*, uint32_t, uint32_t);
lean_object* sdl_destroy_window(lean_object*);
lean_object* sdl_create_renderer(lean_object*);
lean_object* sdl_destroy_renderer(lean_object*);
lean_object* sdl_set_draw_color(lean_object*, uint8_t, uint8_t, uint8_t, uint8_t);
lean_object* sdl_clear(lean_object*);
lean_object* sdl_present(lean_object*);
lean_object* sdl_fill_rect(lean_object*, uint32_t, uint32_t, uint32_t, uint32_t);
lean_object* sdl_load_texture(lean_object*, lean_object*);
lean_object* sdl_destroy_texture(lean_object*);
lean_object* sdl_render_texture_column(lean_object*, lean_object*, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t);
lean_object* sdl_render_columns(lean_object*, lean_object*, lean_object*, uint32_t);
lean_object* sdl_pixel_hash(lean_object*);
lean_object* sdl_poll_event(void);
lean_object* sdl_get_ticks(void);
lean_object* sdl_is_key_pressed(uint32_t);
lean_object* sdl_delay(uint32_t);
