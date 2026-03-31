const std = @import("std");
const vga = @import("vga.zig");

const SerialPort = opaque {};
extern fn init_serial() *SerialPort;
extern fn send_bytes_to_serial(uart: *SerialPort, len: usize, buf: [*]const u8) void;

var uart: *SerialPort = undefined;

pub fn init() void {
    uart = init_serial();
}

export fn handle_rust_panic() callconv(.c) void {
    @panic("Panic in Rust driver");
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

/// Print a string to the serial port.
pub fn printString(str: []const u8) void {
    send_bytes_to_serial(uart, str.len, str.ptr);
}

/// Print with standard Zig format to the serial port.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    var w = writer(&.{});
    w.print(fmt, args) catch return;
}
