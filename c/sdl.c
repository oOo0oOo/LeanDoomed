#include <stdint.h>
#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>
#include <lean/lean.h>

static SDL_Window* g_window = NULL;
static SDL_Renderer* g_renderer = NULL;

uint32_t sdl_get_version(void) {
    // from https://wiki.libsdl.org/SDL3/SDL_GetVersion
    const int linked = SDL_GetVersion();  /* reported by linked SDL library */
    return SDL_VERSIONNUM_MAJOR(linked) * 100 + SDL_VERSIONNUM_MINOR(linked) * 10 + SDL_VERSIONNUM_MICRO(linked);
}

lean_obj_res sdl_init(uint32_t flags, lean_obj_arg w) {
    int32_t result = SDL_Init(flags);
    return lean_io_result_mk_ok(lean_box_uint32(result));
}

lean_obj_res sdl_quit(lean_obj_arg w) {
    if (g_renderer) {
        SDL_DestroyRenderer(g_renderer);
        g_renderer = NULL;
    }
    if (g_window) {
        SDL_DestroyWindow(g_window);
        g_window = NULL;
    }
    SDL_Quit();
    return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res sdl_create_window(lean_obj_arg title, uint32_t w, uint32_t h, uint32_t flags, lean_obj_arg world) {
    const char* title_str = lean_string_cstr(title);
    g_window = SDL_CreateWindow(title_str, (int)w, (int)h, flags);
    if (g_window == NULL) {
        return lean_io_result_mk_ok(lean_box(0));
    }
    return lean_io_result_mk_ok(lean_box(1));
}

lean_obj_res sdl_create_renderer(lean_obj_arg w) {
    if (g_window == NULL) {
        SDL_Log("C: No window available for renderer creation\n");
        return lean_io_result_mk_ok(lean_box(0));
    }
    g_renderer = SDL_CreateRenderer(g_window, NULL);
    if (g_renderer == NULL) {
        const char* error = SDL_GetError();
        SDL_Log("C: SDL_CreateRenderer failed: %s\n", error);
        return lean_io_result_mk_ok(lean_box(0));
    }
    return lean_io_result_mk_ok(lean_box(1));
}

lean_obj_res sdl_set_render_draw_color(uint8_t r, uint8_t g, uint8_t b, uint8_t a, lean_obj_arg w) {
    if (g_renderer == NULL) return lean_io_result_mk_ok(lean_box_uint32(-1));
    int32_t result = SDL_SetRenderDrawColor(g_renderer, r, g, b, a);
    return lean_io_result_mk_ok(lean_box_uint32(result));
}

lean_obj_res sdl_render_clear(lean_obj_arg w) {
    if (g_renderer == NULL) return lean_io_result_mk_ok(lean_box_uint32(-1));
    int32_t result = SDL_RenderClear(g_renderer);
    return lean_io_result_mk_ok(lean_box_uint32(result));
}

lean_obj_res sdl_render_present(lean_obj_arg w) {
    if (g_renderer == NULL) return lean_io_result_mk_ok(lean_box(0));
    SDL_RenderPresent(g_renderer);
    return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res sdl_render_fill_rect(uint32_t x, uint32_t y, uint32_t w, uint32_t h, lean_obj_arg world) {
    if (g_renderer == NULL) return lean_io_result_mk_ok(lean_box_uint32(-1));
    SDL_FRect rect = {(float)x, (float)y, (float)w, (float)h};
    int32_t result = SDL_RenderFillRect(g_renderer, &rect);
    return lean_io_result_mk_ok(lean_box_uint32(result));
}

lean_obj_res sdl_delay(uint32_t ms, lean_obj_arg w) {
    SDL_Delay(ms);
    return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res sdl_poll_event(lean_obj_arg w) {
    SDL_Event event;
    int has_event = SDL_PollEvent(&event);
    return lean_io_result_mk_ok(lean_box_uint32(has_event ? event.type : 0));
}

lean_obj_res sdl_get_ticks(lean_obj_arg w) {
    uint32_t ticks = SDL_GetTicks();
    return lean_io_result_mk_ok(lean_box_uint32(ticks));
}

lean_obj_res sdl_get_key_state(uint32_t scancode, lean_obj_arg w) {
    const uint8_t* state = SDL_GetKeyboardState(NULL);
    uint8_t pressed = state[scancode];
    return lean_io_result_mk_ok(lean_box(pressed));
}