

const std = @import("std");

pub fn main() !void {
    const Cpu = @import("builtin").cpu;
    std.debug.print("CPU architecture: {}\n", .{Cpu.arch});
}
