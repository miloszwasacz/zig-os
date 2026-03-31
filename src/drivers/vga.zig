//! A simple VGA driver for printing text to the screen.
//!
//! Note that functions defined in this module are ***NOT*** thread safe!

const std = @import("std");

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;
const DEFAULT_COLOR = Color.init(.light_gray, .black);

var g_column: usize = 0;
var g_color: Color = DEFAULT_COLOR;
var g_buffer = @as([*]volatile u16, @ptrFromInt(0xB8000));

pub const ColorType = enum(u4) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_gray = 7,
    dark_gray = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    light_brown = 14,
    white = 15,
};

const Color = packed struct(u8) {
    fg: ColorType,
    bg: ColorType,

    pub fn init(fg: ColorType, bg: ColorType) Color {
        return .{ .fg = fg, .bg = bg };
    }

    /// Combine VGA color and char. The upper byte will be color and lower byte will be character.
    pub fn getVgaChar(self: Color, char: u8) u16 {
        return @as(u16, @as(u8, @bitCast(self))) << 8 | char;
    }
};

/// Initialize VGA.
pub fn init() void {
    clear();
}

/// Set Color for VGA.
pub fn setColor(fg: ColorType, bg: ColorType) void {
    g_color = Color.init(fg, bg);
}

/// Clear the screen.
pub fn clear() void {
    @memset(g_buffer[0..VGA_SIZE], Color.getVgaChar(DEFAULT_COLOR, ' '));
    g_column = 0;
}

/// Print character with color at specific position.
pub fn printCharAt(char: u8, color: Color, x: usize, y: usize) void {
    const index = y * VGA_WIDTH + x;
    g_buffer[index] = color.getVgaChar(char);
}

fn printNewLine() void {
    @memmove(g_buffer[0 .. VGA_SIZE - VGA_WIDTH], g_buffer[VGA_WIDTH..VGA_SIZE]);
    @memset(g_buffer[VGA_SIZE - VGA_WIDTH .. VGA_SIZE], Color.getVgaChar(DEFAULT_COLOR, ' '));
    g_column = 0;
}

/// Print a character to the VGA.
pub fn printChar(char: u8) void {
    switch (char) {
        '\n' => printNewLine(),
        else => {
            printCharAt(char, g_color, g_column, VGA_HEIGHT - 1);
            g_column += 1;
            if (g_column == VGA_WIDTH) {
                printNewLine();
            }
        },
    }
}

/// Implementation of std.Io.Writer.vtable.drain function.
/// When flush is called or the writer buffer is full this function is called.
/// This function first writes all data of writer buffer after that it writes
/// the argument data in which the last element is written splat times.
fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
    // The length of the data must not be zero
    std.debug.assert(data.len != 0);

    var consumed: usize = 0;
    const pattern = data[data.len - 1];
    const splat_len = pattern.len * splat;

    // If buffer is not empty, write it first
    if (w.end != 0) {
        printString(w.buffered());
        w.end = 0;
    }

    // Now write all data except the last element
    for (data[0 .. data.len - 1]) |bytes| {
        printString(bytes);
        consumed += bytes.len;
    }

    // If our pattern (i.e. the last element) has non-zero length, write splat times
    switch (pattern.len) {
        0 => {},
        else => {
            for (0..splat) |_| {
                printString(pattern);
            }
        },
    }

    // Now we return how many bytes we consumed from data
    consumed += splat_len;
    return consumed;
}

pub fn writer(buffer: []u8) std.Io.Writer {
    return .{
        .buffer = buffer,
        .end = 0,
        .vtable = &.{
            .drain = drain,
        },
    };
}

/// Print a string to VGA.
pub fn printString(str: []const u8) void {
    for (str) |char| {
        printChar(char);
    }
}

/// Print with standard Zig format to VGA.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    var w = writer(&.{});
    w.print(fmt, args) catch return;
}

test "printString" {
    const str = "Testing string";
    var expected: [str.len]u16 = undefined;
    intoVgaChars(str, &expected);

    clear();
    printString(str);

    try expectLine(&expected);
}

test "print" {
    const str = "I am a formatted string !!11!!";
    var expected: [str.len]u16 = undefined;
    intoVgaChars(str, &expected);

    clear();
    print("I am a formatted string !!{d}!!", .{11});

    try expectLine(&expected);
}

test "new-line" {
    const str = "Oh boy, a new line!";
    var expected: [str.len]u16 = undefined;
    intoVgaChars(str, &expected);

    clear();
    printString(str ++ "\n");

    try std.testing.expect(g_column == 0);
    try expectLineAt(&expected, VGA_SIZE - 2 * VGA_WIDTH);
}

test "setColor+clear" {
    const color = Color.init(ColorType.green, ColorType.blue);
    var expected: [20]u16 = undefined;
    for (0..20) |i| {
        expected[i] = color.getVgaChar('a' + @as(u8, @intCast(i)));
    }

    clear();
    setColor(ColorType.green, ColorType.blue);
    try std.testing.expect(g_color == color);

    for (0..20) |i| {
        printChar('a' + @as(u8, @intCast(i)));
    }
    try expectLine(&expected);

    clear();
    for (0..VGA_SIZE) |i| {
        try std.testing.expect(g_buffer[i] == DEFAULT_COLOR.getVgaChar(' '));
    }
}

fn intoVgaChars(in: []const u8, out: []u16) void {
    for (in, 0..) |c, i| {
        out[i] = Color.getVgaChar(DEFAULT_COLOR, c);
    }
}

fn expectLine(expected: []const u16) !void {
    try expectLineAt(expected, VGA_SIZE - VGA_WIDTH);
}

fn expectLineAt(expected: []const u16, start: usize) !void {
    for (expected, g_buffer[start..]) |exp, act| {
        std.testing.expect(exp == act) catch {
            return error.TestExpectedEqual;
        };
    }
}
