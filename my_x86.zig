const syscall_bits = switch (native_arch) {
    .thumb => std.os.linux.thumb, // arm thumb architecture
    else => arch_bits, // arch_bits is selected
};

pub const SC = arch_bits.SC;


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


// for bind
