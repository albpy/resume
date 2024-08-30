

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();
const std = @import("std");

fn CopyPtrAttrs(
    comptime source: type,
    comptime size: std.builtin.Type.Pointer.Size,
    comptime child: type,
) type {
    const info = @typeInfo(source).Pointer;
    return @Type(.{
        .Pointer = .{
            .size = size,
            .is_const = info.is_const,
            .is_volatile = info.is_volatile,
            .is_allowzero = info.is_allowzero,
            .alignment = info.alignment,
            .address_space = info.address_space,
            .child = child,
            .sentinel = null,
        },
    });
}

fn AsBytesReturnType(comptime P: type) type {
    //meta.Chiled - Given a parameterized type (array, vector, pointer, optional), returns the "child type" using @typeInfo.
    const size = @sizeOf(std.meta.Child(P));
    return CopyPtrAttrs(P, .One, [size]u8);
}

pub fn nativeToBig(comptime T: type, x: T) T {
    return switch (native_endian) {
        // swaps MSB at lowest memory address from LSB at lowest mem address 
        .little => @byteSwap(x),
        .big => x,
    };
}
// Given a pointer to a single item, returns a slice of the underlying bytes, 
// preserving pointer attributes (Pointer Type, Pointer Address, Pointer Safety)
pub fn asBytes(ptr: anytype) AsBytesReturnType(@TypeOf(ptr)) {
    // alignCast - It is used to ensure that a pointer or slice has a specific alignment, which is often necessary for certain operations or when interfacing with hardware.
    // ptrCast - Converts a pointer of one type to a pointer of another type. return type is infered as pointer type.

    return @ptrCast(@alignCast(ptr));
}

// @alignCast does perform runtime checks, to verify that the alignment matches.
// However keep in mind that these are only enabled in debug and ReleaseSafe. So they won’t slow your release builds down. But these checks will help you catch bugs early when running in debug.

// If you have a pointer or a slice that has a small alignment, but you know that it actually has a bigger alignment, use @alignCast to change the pointer into a more aligned pointer. This is a no-op at runtime, but inserts a safety check: 

// redundant - not or no longer needed or useful; superfluous.
// rudimentary - involving or limited to basic principles.
// posterity -all future generations of people.
// harness - control and make use of (natural resources), especially to produce energy.