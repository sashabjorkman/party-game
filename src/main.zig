const std = @import("std");
const sdl = @import("SDL3");
const Renderer = @import("Renderer.zig");
const Ticker = @import("Ticker.zig");
const ecs = @import("ecs.zig");
const F32 = @import("fixed_point.zig").F32;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

    defer if (debug_allocator.deinit() == .leak) {
        std.debug.print("Memory leak detected!", .{});
    };

    const allocator: std.mem.Allocator = debug_allocator.allocator();

    var ticker: Ticker = .init();

    if (!sdl.c.SDL_Init(sdl.c.SDL_INIT_VIDEO | sdl.c.SDL_INIT_AUDIO | sdl.c.SDL_INIT_GAMEPAD)) {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_init;
    }
    defer sdl.c.SDL_Quit();

    std.debug.print("{s} {}\n", .{ "fizz buzz", 21 });

    var renderer: Renderer = try .init("#party", 640, 360, sdl.c.SDL_WINDOW_INPUT_FOCUS | sdl.c.SDL_WINDOW_MOUSE_FOCUS);
    defer renderer.deinit(allocator);

    var running = true;
    var event: sdl.c.SDL_Event = undefined;
    while (running) {
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

        try renderer.render();

        ticker.tick();
    }
}
