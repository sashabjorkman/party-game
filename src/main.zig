const std = @import("std");
const sdl = @import("SDL3");
const Window = @import("Window.zig");

pub fn main() !void {
    if (sdl.c.SDL_Init(
        sdl.c.SDL_INIT_VIDEO |
            sdl.c.SDL_INIT_AUDIO |
            sdl.c.SDL_INIT_GAMEPAD,
    ) == false) return error.sdl_init;
    defer sdl.c.SDL_Quit();

    std.debug.print("{s} {}\n", .{ "fizz buzz", 21 });

    var window = try Window.init();
    defer window.deinit();

    var running = true;
    var event: sdl.c.SDL_Event = undefined;
    while (running) {
        defer sdl.c.SDL_Delay(16);

        while (sdl.c.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.c.SDL_EVENT_KEY_DOWN => {
                    switch (event.key.key) {
                        sdl.c.SDLK_ESCAPE => running = false,
                        else => {},
                    }
                },

                sdl.c.SDL_EVENT_QUIT => running = false,
                else => {},
            }
        }
    }
}
