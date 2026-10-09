#include <stdint.h>
#include <limits.h>
#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>
#include <lean/lean.h>
#include "sdl_abi.h"

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
lean_obj_res sdl_init(uint32_t flags) {
    bool result = SDL_Init(flags);
    return lean_io_result_mk_ok(lean_box(result ? 1 : 0));
}

lean_obj_res sdl_quit(void) {
    SDL_Quit();
    return lean_io_result_mk_ok(lean_box(0));
}

// Window management
lean_obj_res sdl_create_window(b_lean_obj_arg title, uint32_t width, uint32_t height) {
    const char* title_str = lean_string_cstr(title);
    SDL_Window* window = SDL_CreateWindow(title_str, (int32_t)width, (int32_t)height, 0);
    if (window == NULL) {
        return lean_io_result_mk_ok(mk_option_none());
    }
    return lean_io_result_mk_ok(mk_option_some(box_ptr(window)));
}

lean_obj_res sdl_destroy_window(b_lean_obj_arg window_obj) {
    SDL_Window* window = (SDL_Window*)unbox_ptr(window_obj);
    if (window) SDL_DestroyWindow(window);
    return lean_io_result_mk_ok(lean_box(0));
}

// Renderer management
lean_obj_res sdl_create_renderer(b_lean_obj_arg window_obj) {
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

lean_obj_res sdl_destroy_renderer(b_lean_obj_arg renderer_obj) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (renderer) SDL_DestroyRenderer(renderer);
    return lean_io_result_mk_ok(lean_box(0));
}

// Drawing operations
lean_obj_res sdl_set_draw_color(b_lean_obj_arg renderer_obj, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (renderer) SDL_SetRenderDrawColor(renderer, r, g, b, a);
    return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res sdl_clear(b_lean_obj_arg renderer_obj) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (renderer) SDL_RenderClear(renderer);
    return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res sdl_present(b_lean_obj_arg renderer_obj) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (renderer) SDL_RenderPresent(renderer);
    return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res sdl_fill_rect(b_lean_obj_arg renderer_obj, uint32_t x, uint32_t y, uint32_t rw, uint32_t rh) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (renderer) {
        SDL_FRect rect = {(float)(int32_t)x, (float)(int32_t)y, (float)(int32_t)rw, (float)(int32_t)rh};
        SDL_RenderFillRect(renderer, &rect);
    }
    return lean_io_result_mk_ok(lean_box(0));
}

// Texture operations
lean_obj_res sdl_load_texture(b_lean_obj_arg renderer_obj, b_lean_obj_arg filename) {
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

lean_obj_res sdl_destroy_texture(b_lean_obj_arg texture_obj) {
    SDL_Texture* texture = (SDL_Texture*)unbox_ptr(texture_obj);
    if (texture) SDL_DestroyTexture(texture);
    return lean_io_result_mk_ok(lean_box(0));
}

static void draw_texture_column(SDL_Renderer* renderer, SDL_Texture* texture,
                                int32_t dst_x, int32_t dst_y, int32_t dst_height,
                                int32_t src_x, int32_t src_y_start, int32_t src_y_end) {
    int32_t tex_y_start = src_y_start >= 64 ? 0 : src_y_start;
    int32_t tex_y_end = src_y_end > 64 ? 64 : src_y_end;
    if (tex_y_end <= tex_y_start) tex_y_end = tex_y_start + 1;
    SDL_FRect src_rect = {(float)(src_x % 64), (float)tex_y_start, 1.0f, (float)(tex_y_end - tex_y_start)};
    SDL_FRect dst_rect = {(float)dst_x, (float)dst_y, 1.0f, (float)dst_height};
    SDL_RenderTexture(renderer, texture, &src_rect, &dst_rect);
}

lean_obj_res sdl_render_texture_column(b_lean_obj_arg renderer_obj, b_lean_obj_arg texture_obj,
                                     uint32_t dst_x, uint32_t dst_y, uint32_t dst_height,
                                     uint32_t src_x, uint32_t src_y_start, uint32_t src_y_end) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    SDL_Texture* texture = (SDL_Texture*)unbox_ptr(texture_obj);
    if (renderer && texture) {
        draw_texture_column(renderer, texture, (int32_t)dst_x, (int32_t)dst_y,
                            (int32_t)dst_height, (int32_t)src_x, (int32_t)src_y_start, (int32_t)src_y_end);
    }
    return lean_io_result_mk_ok(lean_box(0));
}

lean_obj_res sdl_render_columns(b_lean_obj_arg renderer_obj, b_lean_obj_arg texture_option,
                               b_lean_obj_arg columns, uint32_t screen_height) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    if (!renderer) return lean_io_result_mk_ok(lean_box(0));
    SDL_Texture* texture = lean_obj_tag(texture_option) == 0 ? NULL :
        (SDL_Texture*)unbox_ptr(lean_ctor_get(texture_option, 0));
    size_t count = lean_array_size(columns);
    if (count == 0) return lean_io_result_mk_ok(lean_box(0));
    if (count > INT_MAX || count > SIZE_MAX / sizeof(SDL_FRect))
        return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string("Too many columns")));
    SDL_FRect* rectangles = SDL_malloc(count * sizeof(SDL_FRect));
    if (!rectangles) return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string("Column allocation failed")));
    size_t colors[256] = {0};
    size_t wall_count = 0;
    for (size_t i = 0; i < count; ++i) {
        b_lean_obj_arg column = lean_array_get_core(columns, i);
        // DrawColumn has no object fields: six Int32 scalars followed by shade.
        int32_t x = (int32_t)lean_ctor_get_uint32(column, 0);
        int32_t y = (int32_t)lean_ctor_get_uint32(column, 4);
        int32_t height = (int32_t)lean_ctor_get_uint32(column, 8);
        int32_t tx = (int32_t)lean_ctor_get_uint32(column, 12);
        int32_t ty_start = (int32_t)lean_ctor_get_uint32(column, 16);
        int32_t ty_end = (int32_t)lean_ctor_get_uint32(column, 20);
        uint8_t shade = lean_ctor_get_uint8(column, 24);
        ++colors[shade];
        if (height > 0) {
            if (texture) draw_texture_column(renderer, texture, x, y, height, tx, ty_start, ty_end);
            else rectangles[wall_count++] = (SDL_FRect){(float)x, (float)y, 1.0f, (float)height};
        }
    }
    if (!texture && wall_count > 0) {
        SDL_SetRenderDrawColor(renderer, 180, 80, 50, 255);
        SDL_RenderFillRects(renderer, rectangles, (int)wall_count);
    }
    // Floor columns do not overlap. Group them by color to reduce SDL submissions.
    size_t starts[256], next[256];
    size_t offset = 0;
    for (size_t shade = 0; shade < 256; ++shade) {
        starts[shade] = next[shade] = offset;
        offset += colors[shade];
    }
    for (size_t i = 0; i < count; ++i) {
        b_lean_obj_arg column = lean_array_get_core(columns, i);
        int32_t x = (int32_t)lean_ctor_get_uint32(column, 0);
        int32_t bottom = (int32_t)lean_ctor_get_uint32(column, 4) + (int32_t)lean_ctor_get_uint32(column, 8);
        uint8_t shade = lean_ctor_get_uint8(column, 24);
        rectangles[next[shade]++] = (SDL_FRect){(float)x, (float)bottom, 1.0f, (float)((int32_t)screen_height - bottom)};
    }
    for (size_t shade = 0; shade < 256; ++shade) {
        if (colors[shade] == 0) continue;
        SDL_SetRenderDrawColor(renderer, (uint8_t)shade, (uint8_t)(shade + 30), (uint8_t)shade, 255);
        SDL_RenderFillRects(renderer, rectangles + starts[shade], (int)colors[shade]);
    }
    SDL_free(rectangles);
    return lean_io_result_mk_ok(lean_box(0));
}

// Readback is used by the headless regression tests, outside timed render loops.
lean_obj_res sdl_pixel_hash(b_lean_obj_arg renderer_obj) {
    SDL_Renderer* renderer = (SDL_Renderer*)unbox_ptr(renderer_obj);
    SDL_Surface* raw = SDL_RenderReadPixels(renderer, NULL);
    if (!raw) return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(SDL_GetError())));
    SDL_Surface* surface = SDL_ConvertSurface(raw, SDL_PIXELFORMAT_RGBA32);
    SDL_DestroySurface(raw);
    if (!surface) return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(SDL_GetError())));
    uint64_t hash = UINT64_C(14695981039346656037);
    for (int y = 0; y < surface->h; ++y) {
        const uint8_t* row = (const uint8_t*)surface->pixels + y * surface->pitch;
        for (int x = 0; x < surface->w * 4; ++x) {
            hash = (hash ^ row[x]) * UINT64_C(1099511628211);
        }
    }
    SDL_DestroySurface(surface);
    return lean_io_result_mk_ok(lean_box_uint64(hash));
}

// Input and timing
lean_obj_res sdl_poll_event(void) {
    SDL_Event event;
    int has_event = SDL_PollEvent(&event);
    return lean_io_result_mk_ok(lean_box_uint32(has_event ? event.type : 0));
}

lean_obj_res sdl_get_ticks(void) {
    uint32_t ticks = (uint32_t)SDL_GetTicks();
    return lean_io_result_mk_ok(lean_box_uint32(ticks));
}

lean_obj_res sdl_is_key_pressed(uint32_t scancode) {
    int count = 0;
    const bool* state = SDL_GetKeyboardState(&count);
    bool pressed = state && scancode < (uint32_t)count && state[scancode];
    return lean_io_result_mk_ok(lean_box(pressed ? 1 : 0));
}

lean_obj_res sdl_delay(uint32_t ms) {
    SDL_Delay(ms);
    return lean_io_result_mk_ok(lean_box(0));
}