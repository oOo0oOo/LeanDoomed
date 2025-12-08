#include <stdint.h>
#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>
#include <lean/lean.h>

// Helper macros for Option type
static inline lean_object* mk_option_none() {
    return lean_alloc_ctor(0, 0, 0);
}

static inline lean_object* mk_option_some(lean_object* val) {
    lean_object* opt = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(opt, 0, val);
    return opt;
}

// Box/unbox pointers as opaque types
static inline lean_object* box_ptr(void* ptr) {
    return lean_box_usize((size_t)ptr);
}

static inline void* unbox_ptr(b_lean_obj_arg obj) {
    return (void*)lean_unbox_usize(obj);
}

// Initialization
lean_obj_res sdl_init(uint32_t flags, lean_obj_arg w) {
    bool result = SDL_Init(flags);
    return lean_io_result_mk_ok(lean_box(result ? 1 : 0));
}

lean_obj_res sdl_quit(lean_obj_arg w) {
    SDL_Quit();
    return lean_io_result_mk_ok(lean_box(0));
}

// Window management
lean_obj_res sdl_create_window(b_lean_obj_arg title, int32_t width, int32_t height, lean_obj_arg w) {
    const char* title_str = lean_string_cstr(title);
    SDL_Window* window = SDL_CreateWindow(title_str, width, height, 0);
    if (window == NULL) {
        return lean_io_result_mk_ok(mk_option_none());
    }
    return lean_io_result_mk_ok(mk_option_some(box_ptr(window)));
}

lean_obj_res sdl_destroy_window(b_lean_obj_arg window_obj, lean_obj_arg w) {
    SDL_Window* window = (SDL_Window*)unbox_ptr(window_obj);
    if (window) SDL_DestroyWindow(window);
    return lean_io_result_mk_ok(lean_box(0));
}

// Renderer management
lean_obj_res sdl_create_renderer(b_lean_obj_arg window_obj, lean_obj_arg w) {
    SDL_Window* window = (SDL_Window*)unbox_ptr(window_obj);
    if (window == NULL) {
        return lean_io_result_mk_ok(mk_option_none());
    }
    SDL_Renderer* renderer = SDL_CreateRenderer(window, NULL);
    if (renderer == NULL) {
        SDL_Log("SDL_CreateRenderer failed: %s", SDL_GetError());
        return lean_io_result_mk_ok(mk_option_none());
    }
    return lean_io_result_mk_ok(mk_option_some(box_ptr(renderer)));
}

lean_obj_res sdl_destroy_renderer(b_lean_obj_arg renderer_obj, lean_obj_arg w) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (renderer) SDL_DestroyRenderer(renderer);
    return lean_io_result_mk_ok(lean_box(0));
}

// Drawing operations
lean_obj_res sdl_set_draw_color(b_lean_obj_arg renderer_obj, uint8_t r, uint8_t g, uint8_t b, uint8_t a, lean_obj_arg w) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (renderer) SDL_SetRenderDrawColor(renderer, r, g, b, a);
    return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res sdl_clear(b_lean_obj_arg renderer_obj, lean_obj_arg w) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (renderer) SDL_RenderClear(renderer);
    return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res sdl_present(b_lean_obj_arg renderer_obj, lean_obj_arg w) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (renderer) SDL_RenderPresent(renderer);
    return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res sdl_fill_rect(b_lean_obj_arg renderer_obj, int32_t x, int32_t y, int32_t rw, int32_t rh, lean_obj_arg w) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (renderer) {
        SDL_FRect rect = {(float)x, (float)y, (float)rw, (float)rh};
        SDL_RenderFillRect(renderer, &rect);
    }
    return lean_io_result_mk_ok(lean_box(0));
}

// Texture operations
lean_obj_res sdl_load_texture(b_lean_obj_arg renderer_obj, b_lean_obj_arg filename, lean_obj_arg w) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (renderer == NULL) {
        return lean_io_result_mk_ok(mk_option_none());
    }
    const char* filename_str = lean_string_cstr(filename);
    SDL_Surface* surface = IMG_Load(filename_str);
    if (!surface) {
        SDL_Log("Failed to load texture: %s", SDL_GetError());
        return lean_io_result_mk_ok(mk_option_none());
    }
    SDL_Texture* texture = SDL_CreateTextureFromSurface(renderer, surface);
    SDL_DestroySurface(surface);
    if (!texture) {
        SDL_Log("Failed to create texture: %s", SDL_GetError());
        return lean_io_result_mk_ok(mk_option_none());
    }
    return lean_io_result_mk_ok(mk_option_some(box_ptr(texture)));
}

lean_obj_res sdl_destroy_texture(b_lean_obj_arg texture_obj, lean_obj_arg w) {
    SDL_Texture* texture = (SDL_Texture*)unbox_ptr(texture_obj);
    if (texture) SDL_DestroyTexture(texture);
    return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res sdl_render_texture_column(b_lean_obj_arg renderer_obj, b_lean_obj_arg texture_obj,
                                        int32_t dst_x, int32_t dst_y, int32_t dst_height,
                                        int32_t src_x, int32_t src_y_start, int32_t src_y_end,
                                        lean_obj_arg w) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    SDL_Texture* texture = (SDL_Texture*)unbox_ptr(texture_obj);
    if (!renderer || !texture) {
        return lean_io_result_mk_ok(lean_box(0));
    }

    int32_t tex_y_start = src_y_start >= 64 ? 0 : src_y_start;
    int32_t tex_y_end = src_y_end > 64 ? 64 : src_y_end;
    if (tex_y_end <= tex_y_start) tex_y_end = tex_y_start + 1;

    SDL_FRect src_rect = {(float)(src_x % 64), (float)tex_y_start, 1.0f, (float)(tex_y_end - tex_y_start)};
    SDL_FRect dst_rect = {(float)dst_x, (float)dst_y, 1.0f, (float)dst_height};

    SDL_RenderTexture(renderer, texture, &src_rect, &dst_rect);
    return lean_io_result_mk_ok(lean_box(0));
}

// Input and timing
lean_obj_res sdl_poll_event(lean_obj_arg w) {
    SDL_Event event;
    int has_event = SDL_PollEvent(&event);
    return lean_io_result_mk_ok(lean_box_uint32(has_event ? event.type : 0));
}

lean_obj_res sdl_get_ticks(lean_obj_arg w) {
    uint32_t ticks = (uint32_t)SDL_GetTicks();
    return lean_io_result_mk_ok(lean_box_uint32(ticks));
}

lean_obj_res sdl_is_key_pressed(uint32_t scancode, lean_obj_arg w) {
    const bool* state = SDL_GetKeyboardState(NULL);
    bool pressed = state[scancode];
    return lean_io_result_mk_ok(lean_box(pressed ? 1 : 0));
}

lean_obj_res sdl_delay(uint32_t ms, lean_obj_arg w) {
    SDL_Delay(ms);
    return lean_io_result_mk_ok(lean_box(0));
}