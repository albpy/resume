

const my_posix = @import("my_posix.zig");

const my_linux = @import("my_linux.zig");

const std = @import("std");

const native_arch = my_posix.builtin.cpu.arch;

const is_mips = native_arch.isMIPS();

const is_ppc = native_arch.isPPC();

const is_ppc64 = native_arch.isPPC64();

const is_sparc = native_arch.isSPARC();

const native_os = my_posix.builtin.os.tag;

const my_net = @import("my_net.zig");

pub const UnexpectedError = @import("my_err.zig").UnexpectedError;
pub const SetSockOptError = @import("my_err.zig").SetSockOptError;
pub const GetSockNameError = @import("my_err.zig").GetSockNameError;
pub const ListenError = @import("my_err.zig").ListenError;
pub const BindError =  @import("my_err.zig").BindError;
pub const my_err = @import("my_err.zig");

pub const E = system.E;



const syscall_bits = switch (native_arch) {
    .thumb => @import("/home/albin/Downloads/zig-linux-x86_64-0.14.0-dev.185+c40708a2c/lib/std/os/linux/thumb.zig"),
    else => my_linux.arch_bits,
};

const linux = std.os.linux;
const windows = std.os.windows;
const wasi = std.os.wasi;


pub const socketcall = syscall_bits.socketcall;
pub const SC = my_linux.arch_bits.SC;

pub const syscall3 = syscall_bits.syscall3;
pub const syscall5 = syscall_bits.syscall5;






/// Whether to use libc for the POSIX API layer.
const use_libc = my_posix.builtin.link_libc or switch (native_os) {
    .windows, .wasi => true,
    else => false,
};


/// A libc-compatible API layer.
pub const system = if (use_libc)
    std.c
else switch (native_os) {
    .linux => linux,
    .plan9 => std.os.plan9,
    else => struct {},
};












