pub const F32 = packed struct(i32) {
    const integer_bits = 16;
    const fractional_bits = 16;

    bits: i32,

    /// Initialize a fixed point number with inferred arguments.
    pub inline fn init(initializer: anytype) F32 {
        return @bitCast(infer(initializer));
    }

    /// Returns the sum of two fixed point numbers.
    pub inline fn add(augend: F32, addend: anytype) F32 {
        return @bitCast(augend.bits + infer(addend));
    }

    /// Returns the difference of two fixed point numbers.
    pub inline fn sub(minuend: F32, subtrahend: anytype) F32 {
        return @bitCast(minuend.bits - infer(subtrahend));
    }

    /// Returns the product of two fixed point numbers.
    pub inline fn mul(multiplicand: F32, multiplier: anytype) F32 {
        return switch (@typeInfo(@TypeOf(multiplier))) {
            inline .int, .comptime_int => @bitCast(multiplicand.bits * @as(i32, multiplier)),
            inline else => @bitCast(@as(i32, @intCast((@as(i64, multiplicand.bits) * @as(i64, infer(multiplier))) >> fractional_bits))),
        };
    }

    /// Returns the quotient of two fixed point numbers.
    pub inline fn div(dividend: F32, divisor: anytype) F32 {
        return switch (@typeInfo(@TypeOf(divisor))) {
            inline .int, .comptime_int => @bitCast(@divTrunc(dividend.bits, @as(i32, divisor))),
            inline else => @bitCast(@as(i32, @intCast(@divTrunc(@as(i64, dividend.bits) << fractional_bits, @as(i64, infer(divisor)))))),
        };
    }

    /// Returns the absoulute value of a fixed point number.
    pub inline fn abs(self: F32) F32 {
        return @bitCast(@as(i32, @intCast(@abs(self.bits))));
    }

    /// Returns the integer square of a fixed point number.
    pub inline fn sqr(self: F32) F32 {
        return mul(self, self);
    }

    /// Source: Jonathan Hallström.
    /// Returns the square root of a fixed point number.
    pub inline fn sqrt(self: F32) F32 {
        if (self.bits < 0) {
            unreachable;
        }

        const n = @as(i64, self.bits) << fractional_bits;
        var x: i32 = infer(@sqrt(asFloat(self))) + 1;

        if (@as(i64, x) * @as(i64, x) > n) {
            x -= 1;
        }

        if (@as(i64, x + 1) * @as(i64, x + 1) <= n) {
            x += 1;
        }

        return @bitCast(x);
    }

    /// Compares two fixed point numbers.
    pub inline fn cmp(a: F32, b: anytype, comptime op: enum { eq, ne, gt, ge, lt, le }) bool {
        return switch (op) {
            .eq => a.bits == infer(b),
            .ne => a.bits != infer(b),
            .gt => a.bits > infer(b),
            .ge => a.bits >= infer(b),
            .lt => a.bits < infer(b),
            .le => a.bits <= infer(b),
        };
    }

    /// Returns the floored integer representation of a fixed point number.
    pub inline fn asInt(self: F32) i16 {
        return @truncate(self.bits >> fractional_bits);
    }

    /// Returns the floating point representation of a fixed point number.
    pub inline fn asFloat(self: F32) f32 {
        return @as(f32, @floatFromInt(self.bits)) / (1 << fractional_bits);
    }

    /// Safely casts a value to its fixed point representation.
    pub inline fn infer(value: anytype) i32 {
        const Type = @TypeOf(value);
        const info = @typeInfo(Type);

        if (Type == F32) {
            return value.bits;
        }

        return switch (info) {
            inline .int, .comptime_int => @as(i32, @as(i16, value)) << fractional_bits,
            inline .float, .comptime_float => @as(i32, @intFromFloat(value * (1 << fractional_bits))),
            inline else => @compileError("Expected fixed point, floating point, or integer type, but got type " ++ @typeName(Type)),
        };
    }
};
