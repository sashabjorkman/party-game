const sdl = @import("SDL3");

const Window = @This();

handle: *sdl.c.SDL_Window = undefined,
renderer: *sdl.c.SDL_Renderer = undefined,

pub const Error = error{
    create_window,
    create_renderer,
};

// resolutions:
// - 640  x 360
// - 960  x 540
// - 1280 x 720
// - 1920 x 1080

pub fn init() Error!Window {
    const handle = sdl.c.SDL_CreateWindow(
        "#party",
        640,
        360,
        sdl.c.SDL_WINDOW_INPUT_FOCUS | sdl.c.SDL_WINDOW_MOUSE_FOCUS,
    ) orelse return Error.create_window;
    const renderer = sdl.c.SDL_CreateRenderer(handle, null) orelse return Error.create_renderer;

    return Window{
        .handle = handle,
        .renderer = renderer,
    };
}

pub fn deinit(window: *Window) void {
    sdl.c.SDL_DestroyRenderer(window.renderer);
    sdl.c.SDL_DestroyWindow(window.handle);
}
