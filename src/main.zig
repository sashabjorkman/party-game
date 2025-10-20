const std = @import("std");
const sdl = @import("SDL3");
const Window = @import("Window.zig");
const ecs = @import("ecs.zig");
const F32 = @import("fixed_point.zig").F32;

const Position = struct {
    x: F32,
    y: F32,
};

const Velocity = struct {
    x: F32,
    y: F32,
};

fn moveSystem(comptime registry: ecs.Registry, world: *ecs.World(registry)) void {
    var query = world.query(&.{ Position, Velocity }, &.{});

    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const velocity = query.get(entity, Velocity);

        position.x = F32.add(position.x, velocity.x);
        position.y = F32.add(position.y, velocity.y);
    }
}

pub fn main() !void {
    var world: ecs.World(.{ .entities = 256, .components = &.{ Position, Velocity } }) = .new;

    const entity = try world.spawn(.{
        Position{
            .x = .init(0),
            .y = .init(0),
        },
        Velocity{
            .x = .init(0.1),
            .y = .init(0.1),
        },
    });

    for (0..10) |_| {
        moveSystem(world.registry, &world);
        const position = try world.inspect(entity, Position);
        std.debug.print("{}, {}\n", .{ position.x.asFloat(), position.y.asFloat() });
    }

    try world.kill(entity);

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
