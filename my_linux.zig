// syscall args from std.os.linux.syscalls.zig


pub const my_posix = @import("my_posix.zig");

const native_arch = my_posix.builtin.cpu.arch;

const std = @import("std");
// from lib/std/os/linux.zig


const syscall_bits = switch (native_arch) {
    .thumb => std.os.linux.thumb, // arm thumb architecture
    else => arch_bits, // arch_bits is selected
};

const linux = std.os.linux;
const windows = std.os.windows;
const wasi = std.os.wasi;

pub const SC = arch_bits.SC;

pub const socketcall = syscall_bits.socketcall;

pub const syscall1 = syscall_bits.syscall1;
pub const syscall2 = syscall_bits.syscall2;
pub const syscall3 = syscall_bits.syscall3;
pub const syscall5 = syscall_bits.syscall5;

// defining a constant arch_bits based on the native architecture of the system and 
// the switch statement is then used to determine which architecture-specific module to import based on native_arch.
pub const pid_t = i32;
pub const fd_t = i32;
pub const socket_t = i32;
pub const uid_t = u32;
pub const gid_t = u32;
pub const clock_t = isize;


pub const socklen_t = u32;


pub const arch_bits = switch (native_arch) {
    .x86 => @import("/home/albin/Downloads/zig-linux-x86_64-0.14.0/lib/std/os/linux/x86.zig"),
    .x86_64 => @import("/home/albin/Downloads/zig-linux-x86_64-0.14.0/lib/std/os/linux/x86_64.zig"),
    .aarch64, .aarch64_be => @import("/home/albin/Downloads/zig-linux-x86_64-0.14.0/lib/std/os/linux/arm64.zig"),
    .arm, .thumb => @import("/home/albin/Downloads/zig-linux-x86_64-0.14.0/lib/std/os/linux/arm-eabi.zig"),
    .riscv64 => @import("/home/albin/Downloads/zig-linux-x86_64-0.14.0/lib/std/os/linux/riscv64.zig"),
    .sparc64 => @import("/home/albin/Downloads/zig-linux-x86_64-0.14.0/lib/std/os/linux/sparc64.zig"),
    .mips, .mipsel => @import("/home/albin/Downloads/zig-linux-x86_64-0.14.0/lib/std/os/linux/mips.zig"),
    .mips64, .mips64el => @import("/home/albin/Downloads/zig-linux-x86_64-0.14.0/lib/std/os/linux/mips64.zig"),
    .powerpc, .powerpcle => @import("/home/albin/Downloads/zig-linux-x86_64-0.14.0/lib/std/os/linux/powerpc.zig"),
    .powerpc64, .powerpc64le => @import("/home/albin/Downloads/zig-linux-x86_64-0.14.0/lib/std/os/linux/powerpc64.zig"),
    else => struct {
        pub const ucontext_t = void;
        pub const getcontext = {};
    },
};
pub const F = arch_bits.F;
pub const FD_CLOEXEC = 1;

// setsockopt from linux.zig
pub fn setsockopt(fd: i32, level: i32, optname: u32, optval: [*]const u8, optlen: socklen_t) usize {
    if (native_arch == .x86) {
        return socketcall(SC.setsockopt, &[5]usize{ @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, level))), optname, @intFromPtr(optval), @as(usize, @intCast(optlen)) });
    }
    return syscall5(.setsockopt, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, level))), optname, @intFromPtr(optval), @as(usize, @intCast(optlen)));
}

pub fn fcntl(fd: fd_t, cmd: i32, arg: usize) usize {
    return syscall3(.fcntl, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, cmd))), arg);
}

// from linux.zig
pub fn socket(domain: u32, socket_type: u32, protocol: u32) !usize {
    // domain - domain of the protocol; 2
    // socket_type : protocol flags; 524289
    // protocol - for us tcp ; 6
    if (native_arch == .x86) {
        // socketcall: This is a legacy method used on older Linux systems (primarily on x86). 
        // It performs various socket-related system calls using a single entry point.
        // SC.socket indicates the type of socket operation.
        return socketcall(SC.socket, &[3]usize{ domain, socket_type, protocol });
    }
    // from std.os.linux.syscall.zig 41,
    //The syscall instruction is executed. 
    //This is a special CPU instruction that transitions the processor to kernel mode and executes the system call specified by the rax register.
    return syscall3(.socket, domain, socket_type, protocol); // from zig/lib/std/os/linux/x86_64.zig
}

pub fn close(fd: i32) usize {
    return syscall1(.close, @as(usize, @bitCast(@as(isize, fd))));
}
// Bind a name to a socket
pub fn bind(fd: i32, addr: *const std.os.linux.sockaddr, len: socklen_t) usize {
    if (native_arch == .x86) {
        return socketcall(SC.bind, &[3]usize{ @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @as(usize, @intCast(len)) });
    }
    return syscall3(.bind, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @as(usize, @intCast(len)));
// pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
//     return asm volatile ("syscall"
//         : [ret] "={rax}" (-> usize),
//         : [number] "{rax}" (@intFromEnum(number)),
//           [arg1] "{rdi}" (arg1),
//           [arg2] "{rsi}" (arg2),
//           [arg3] "{rdx}" (arg3),
//         : "rcx", "r11", "memory"
//     );
// }
}

pub fn listen(fd: i32, backlog: u32) usize {
    if (native_arch == .x86) {
        return socketcall(SC.listen, &[2]usize{ @as(usize, @bitCast(@as(isize, fd))), backlog });
    }
    return syscall2(.listen, @as(usize, @bitCast(@as(isize, fd))), backlog);
}

pub fn getsockname(fd: i32, noalias addr: *std.os.linux.sockaddr, noalias len: *socklen_t) usize {
    if (native_arch == .x86) {
        return socketcall(SC.getsockname, &[3]usize{ @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @intFromPtr(len) });
    }
    return syscall3(.getsockname, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @intFromPtr(len));
}





// // Syscall	Number	Description
// SOCKET   	41	    Create an endpoint for communication
// SOCKETPAIR	53	    Create a pair of connected sockets
// SETSOCKOPT	54	    Set options on sockets
// GETSOCKOPT	55	    Get options on sockets
// GETSOCKNAME	51	    Get socket name
// GETPEERNAME	52	    Get name of connected peer socket
// BIND	        49	    Bind a name to a socket
// LISTEN	    50	    Listen for connections on a socket
// ACCEPT	    43	    Accept a connection on a socket
// ACCEPT4	    288	    Accept a connection on a socket
// CONNECT	    42	    Initiate a connection on a socket
// SHUTDOWN	    48	    Shut down part of a full-duplex connection


// Send/Receive
// RECVFROM	    45	    Receive a message from a socket
// RECVMSG	    47	    Receive a message from a socket
// RECVMMSG	    299	    Receive multiple messages from a socket
// SENDTO	    44	    Send a message on a socket
// SENDMSG	    46	    Send a message on a socket
// SENDMMSG	    307	    Send multiple messages on a socket

// Naming
// SETHOSTNAME	  170   Set hostname
// SETDOMAINNAME  171	Set NIS domain name

// Packet filtering
// Syscall	Number	Description
// BPF	    321	    Perform a command on an extended BPF map or program