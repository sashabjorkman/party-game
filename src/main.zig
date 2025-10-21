const std = @import("std");

const Window = @import("input/Window.zig");
const Input = @import("input/Input.zig");

pub fn main() !void {
    var window = try Window.init();
    defer window.deinit();

    var input = Input.init();
    defer input.deinit();

    const Player = struct {
        pub const Occupation = enum {
            free,
            occupied,
        };

        occupation: Occupation = .free,
        mapped_device: u8 = undefined,
    };

    var players: [Input.Device.max_count]Player = [_]Player{.{}} ** Input.Device.max_count;

    var running = true;
    while (running) {
        const defered_events = input.pollEvents(&window);

        switch (defered_events) {
            .escape, .terminate => running = false,
            .none => {},
        }

        // pair a local device with a player
        for (&input.local_devices, 0..) |*device, device_index| {
            for (&players, 0..) |*player, player_index| {
                if (device.assignment == .wants_assignment and player.occupation == .free) {
                    player.occupation = .occupied;
                    player.mapped_device = @truncate(device_index);

                    device.assignment = .assigned;
                    device.mapped_player = @truncate(player_index);

                    std.log.info("Mapped device {} to player {}", .{ device_index, player_index });
                }
            }
        }

        // debug
        std.log.info(
            "dpad: {} | a: {t} | b: {t}",
            .{ input.local_devices[0].dpad, input.local_devices[0].button_a, input.local_devices[0].button_b },
        );

        std.Thread.sleep(500 * std.time.ns_per_ms);
    }
}
