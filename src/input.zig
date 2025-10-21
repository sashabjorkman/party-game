pub const Joystick = enum(u4) {
    neutral = 0b0000,
    up = 0b0001,
    down = 0b0010,
    left = 0b0100,
    right = 0b1000,
    up_left = 0b0101,
    up_right = 0b1001,
    down_left = 0b0110,
    down_right = 0b1010,
};

pub const Button = enum(u2) {
    up = 0b00,
    down = 0b01,
    just_released = 0b10,
    just_pressed = 0b11,

    pub inline fn isUpOrReleased(self: Button) bool {
        return @as(u2, @bitCast(self)) & 0b01 == 0;
    }

    pub inline fn isDownOrPressed(self: Button) bool {
        return @as(u2, @bitCast(self)) & 0b01 == 1;
    }

    pub inline fn getNextFrameButton(self: Button) Button {
        return @bitCast(@as(u2, @bitCast(self)) & 0b01);
    }
};

pub const Status = packed struct(u16) {
    _: u16 = 0,
};

pub const Controller = packed struct(u32) {
    joystick: Joystick = .neutral,
    button_a: Button = .up,
    button_b: Button = .up,
    button_c: Button = .up,
    button_x: Button = .up,
    button_y: Button = .up,
    button_z: Button = .up,
    status: Status = .{},
};
