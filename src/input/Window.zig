const sdl = @import("SDL3");

const Window = @This();

pub const Error = error{
    sdl_init,
    create_window,
};

handle: *sdl.c.SDL_Window = undefined,

// resolutions:
// - 640  x 360
// - 960  x 540
// - 1280 x 720
// - 1920 x 1080

/// This function also initializes SDL3
pub fn init() Error!Window {
    if (!sdl.c.SDL_Init(
        sdl.c.SDL_INIT_VIDEO | sdl.c.SDL_INIT_GAMEPAD | sdl.c.SDL_INIT_AUDIO,
    )) return Error.sdl_init;

    const handle = sdl.c.SDL_CreateWindow(
        "#party",
        640,
        360,
        sdl.c.SDL_WINDOW_INPUT_FOCUS | sdl.c.SDL_WINDOW_MOUSE_FOCUS,
    ) orelse return Error.create_window;

    return Window{
        .handle = handle,
    };
}

/// This function also deinitializes SDL3
pub fn deinit(window: *Window) void {
    sdl.c.SDL_DestroyWindow(window.handle);
    sdl.c.SDL_Quit();
}
