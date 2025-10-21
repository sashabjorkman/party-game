const Renderer = @This();

const std = @import("std");
const sdl = @import("SDL3");

window: *sdl.c.SDL_Window,
renderer: *sdl.c.SDL_Renderer,
canvas: *sdl.c.SDL_Texture,

textures: std.StringArrayHashMapUnmanaged(*sdl.c.SDL_Texture),

pub fn init(title: []const u8, width: u16, height: u16, flags: u64) !Renderer {
    const window: *sdl.c.SDL_Window = sdl.c.SDL_CreateWindow(@ptrCast(title), width, height, flags) orelse {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_create_window;
    };

    errdefer sdl.c.SDL_DestroyWindow(window);

    const renderer: *sdl.c.SDL_Renderer = sdl.c.SDL_CreateRenderer(window, null) orelse {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_create_renderer;
    };

    errdefer sdl.c.SDL_DestroyRenderer(renderer);

    const canvas: *sdl.c.SDL_Texture = sdl.c.SDL_CreateTexture(renderer, sdl.c.SDL_PIXELFORMAT_ARGB32, sdl.c.SDL_TEXTUREACCESS_TARGET, width, height) orelse {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_create_texture;
    };

    errdefer sdl.c.SDL_DestroyTexture(canvas);

    if (!sdl.c.SDL_SetWindowResizable(window, true)) {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_set_window_resizable;
    }

    if (!sdl.c.SDL_SetTextureScaleMode(canvas, sdl.c.SDL_SCALEMODE_NEAREST)) {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_set_texture_scale_mode;
    }

    return Renderer{
        .window = window,
        .renderer = renderer,
        .canvas = canvas,
        .textures = .{},
    };
}

pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
    for (self.textures.values()) |texture| {
        sdl.c.SDL_DestroyTexture(texture);
    }

    self.textures.deinit(allocator);
    sdl.c.SDL_DestroyTexture(self.canvas);
    sdl.c.SDL_DestroyRenderer(self.renderer);
    sdl.c.SDL_DestroyWindow(self.window);
}

// pub fn loadTexture(self: *Renderer, allocator: std.mem.Allocator, path: [:0]const u8) !*const sdl.c.SDL_Texture {
//     const result = try self.textures.getOrPut(allocator, path);

//     if (!result.found_existing) {
//         result.value_ptr.* = try sdl.c.loadTexture(self.renderer, path);
//     }

//     return result.value_ptr.value;
// }

pub fn render(self: Renderer) !void {
    // Draw on canvas

    if (!sdl.c.SDL_SetRenderTarget(self.renderer, self.canvas)) {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_set_render_target;
    }

    if (!sdl.c.SDL_SetRenderDrawColor(self.renderer, 128, 32, 128, 255)) {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_set_render_draw_color;
    }

    if (!sdl.c.SDL_RenderClear(self.renderer)) {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_render_clear;
    }

    // Draw canvas

    if (!sdl.c.SDL_SetRenderTarget(self.renderer, null)) {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_set_render_target;
    }

    if (!sdl.c.SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 255)) {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_set_render_draw_color;
    }

    if (!sdl.c.SDL_RenderClear(self.renderer)) {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_render_clear;
    }

    if (!sdl.c.SDL_RenderTexture(self.renderer, self.canvas, null, null)) {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_render_texture;
    }

    if (!sdl.c.SDL_RenderPresent(self.renderer)) {
        std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
        return error.sdl_render_present;
    }
}
