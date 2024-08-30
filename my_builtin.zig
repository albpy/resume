

pub const builtin = @import("builtin");

const std = @import("std");

const is_mips = builtin.cpu.arch.isMIPS();

const is_ppc = builtin.cpu.arch.isPPC();

const is_ppc64 = builtin.cpu.arch.isPPC64();

const is_sparc = builtin.cpu.arch.isSPARC();

const is_x86 = builtin.cpu.arch.isX86();

pub fn main() !void {
    std.debug.print("CPU architecture: {}\n", .{builtin.cpu.arch});
    std.debug.print("CPU MIPS: {}\n", .{is_mips});
    std.debug.print("CPU PPC: {}\n", .{is_ppc});
    std.debug.print("CPU PPC64: {}\n", .{is_ppc64});
    std.debug.print("CPU SPARC: {}\n", .{is_sparc});
    std.debug.print("CPU X86: {}\n", .{is_x86});
    std.debug.print("os.tag: {}\n", .{builtin.os.tag});

}

