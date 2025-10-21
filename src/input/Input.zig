const std = @import("std");
const sdl = @import("SDL3");
const Window = @import("Window.zig");

const Input = @This();

// idk if this even can fail
pub const Error = error{};

const keyboard_wasd_index: comptime_int = 0;
const keyboard_ijkl_index: comptime_int = 1;

pub const Device = struct {
    pub const max_count: comptime_int = 16;

    pub const AssignmentState = enum {
        unassigned,
        assigned,
        wants_assignment,
    };

    pub const ButtonState = enum {
        held,
        not_held,
        pressed,
        released,
    };

    mapped_player: u8 = undefined,

    assignment: AssignmentState = .unassigned,
    dpad: u4 = 0, // bits left to right, up -> down -> left -> right
    button_a: ButtonState = .not_held,
    button_b: ButtonState = .not_held,
};

local_devices: [Device.max_count]Device = [_]Device{.{}} ** Device.max_count,

pub fn init() Input {
    return Input{};
}

pub fn deinit(input: *Input) void {
    @memset(&input.local_devices, Device{});
}

pub const EventsToHandle = enum(u2) {
    none = 0b00,
    escape = 0b01,
    terminate = 0b11,
};

/// All SDL events are polled here. This should be the very
/// first or very last thing you do in a frame.
///
/// Some events are directly tied to game state and
/// are returned to be handled later.
pub fn pollEvents(input: *Input, _: *const Window) EventsToHandle {
    input.updateButtonHeldStates();

    var events_to_handle: u2 = 0;

    var event: sdl.c.SDL_Event = undefined;
    while (sdl.c.SDL_PollEvent(&event)) {
        switch (event.type) {
            sdl.c.SDL_EVENT_KEY_DOWN => {
                switch (event.key.key) {
                    sdl.c.SDLK_W,
                    sdl.c.SDLK_A,
                    sdl.c.SDLK_S,
                    sdl.c.SDLK_D,
                    sdl.c.SDLK_X,
                    sdl.c.SDLK_Z,
                    => |k| input.handleKeyboardWASD(k, .press),

                    sdl.c.SDLK_I,
                    sdl.c.SDLK_J,
                    sdl.c.SDLK_K,
                    sdl.c.SDLK_L,
                    sdl.c.SDLK_N,
                    sdl.c.SDLK_M,
                    => |k| input.handleKeyboardIJKL(k, .press),

                    sdl.c.SDLK_ESCAPE => events_to_handle |= @intFromEnum(EventsToHandle.escape),
                    else => {},
                }
            },

            sdl.c.SDL_EVENT_KEY_UP => {
                switch (event.key.key) {
                    sdl.c.SDLK_W,
                    sdl.c.SDLK_A,
                    sdl.c.SDLK_S,
                    sdl.c.SDLK_D,
                    sdl.c.SDLK_X,
                    sdl.c.SDLK_Z,
                    => |k| input.handleKeyboardWASD(k, .release),

                    sdl.c.SDLK_I,
                    sdl.c.SDLK_J,
                    sdl.c.SDLK_K,
                    sdl.c.SDLK_L,
                    sdl.c.SDLK_N,
                    sdl.c.SDLK_M,
                    => |k| input.handleKeyboardIJKL(k, .release),

                    sdl.c.SDLK_ESCAPE => events_to_handle |= @intFromEnum(EventsToHandle.escape),
                    else => {},
                }
            },

            sdl.c.SDL_EVENT_QUIT => events_to_handle |= @intFromEnum(EventsToHandle.terminate),
            else => {},
        }
    }

    return @enumFromInt(events_to_handle);
}

inline fn updateButtonHeldStates(input: *Input) void {
    for (&input.local_devices) |*device| {
        if (device.assignment == .assigned) {
            device.button_a = switch (device.button_a) {
                .held, .pressed => .held,
                .not_held, .released => .not_held,
            };

            device.button_b = switch (device.button_b) {
                .held, .pressed => .held,
                .not_held, .released => .not_held,
            };
        }
    }
}

const KeyEvent = enum { press, release };

fn handleKeyboardWASD(input: *Input, key: u32, event: KeyEvent) void {
    const wasd = &input.local_devices[keyboard_wasd_index];
    if (wasd.assignment == .unassigned) {
        wasd.assignment = .wants_assignment;
    }

    switch (event) {
        .press => {
            switch (key) {
                sdl.c.SDLK_W => wasd.dpad |= 0b1000,
                sdl.c.SDLK_S => wasd.dpad |= 0b0100,
                sdl.c.SDLK_A => wasd.dpad |= 0b0010,
                sdl.c.SDLK_D => wasd.dpad |= 0b0001,

                sdl.c.SDLK_Z => wasd.button_a = if (wasd.button_a != .held) .pressed else .held,
                sdl.c.SDLK_X => wasd.button_b = if (wasd.button_b != .held) .pressed else .held,
                else => {},
            }
        },
        .release => {
            switch (key) {
                sdl.c.SDLK_W => wasd.dpad &= 0b0111,
                sdl.c.SDLK_S => wasd.dpad &= 0b1011,
                sdl.c.SDLK_A => wasd.dpad &= 0b1101,
                sdl.c.SDLK_D => wasd.dpad &= 0b1110,

                sdl.c.SDLK_Z => wasd.button_a = if (wasd.button_a != .not_held) .released else .not_held,
                sdl.c.SDLK_X => wasd.button_b = if (wasd.button_b != .not_held) .released else .not_held,
                else => {},
            }
        },
    }
}

fn handleKeyboardIJKL(input: *Input, key: u32, event: KeyEvent) void {
    const ijkl = &input.local_devices[keyboard_ijkl_index];
    if (ijkl.assignment == .unassigned) {
        ijkl.assignment = .wants_assignment;
    }

    switch (event) {
        .press => {
            switch (key) {
                sdl.c.SDLK_I => ijkl.dpad |= 0b1000,
                sdl.c.SDLK_J => ijkl.dpad |= 0b0100,
                sdl.c.SDLK_K => ijkl.dpad |= 0b0010,
                sdl.c.SDLK_L => ijkl.dpad |= 0b0001,

                sdl.c.SDLK_N => ijkl.button_a = if (ijkl.button_a != .held) .pressed else .held,
                sdl.c.SDLK_M => ijkl.button_b = if (ijkl.button_b != .held) .pressed else .held,
                else => {},
            }
        },
        .release => {
            switch (key) {
                sdl.c.SDLK_I => ijkl.dpad &= 0b0111,
                sdl.c.SDLK_J => ijkl.dpad &= 0b1011,
                sdl.c.SDLK_K => ijkl.dpad &= 0b1101,
                sdl.c.SDLK_L => ijkl.dpad &= 0b1110,

                sdl.c.SDLK_N => ijkl.button_a = if (ijkl.button_a != .not_held) .released else .not_held,
                sdl.c.SDLK_M => ijkl.button_b = if (ijkl.button_b != .not_held) .released else .not_held,
                else => {},
            }
        },
    }
}
