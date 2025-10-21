const Ticker = @This();

const sdl = @import("SDL3");

/// Frames per second.
const framerate = 60;

/// Nanoseconds per frame.
const frametime = 1_000_000_000 / framerate;

ticks: u64,

pub fn init() Ticker {
    return Ticker{ .ticks = sdl.c.SDL_GetTicksNS() };
}

pub fn tick(self: *Ticker) void {
    const deltatime = sdl.c.SDL_GetTicksNS() -% self.ticks;

    if (deltatime <= frametime) {
        sdl.c.SDL_DelayPrecise(frametime -% deltatime);
    }

    self.ticks += frametime;
}
