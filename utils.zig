

const std = @import("std");
const posix = std.posix;
//pub const sockaddr = system.sockaddr;
const builtin = @import("builtin");
const native_os = builtin.os.tag; 
const assert = std.debug.assert;
const posix_constants = @import("posix_constants.zig");
const AF = posix_constants.AF;
const mem = std.mem;
const sysutil = @import("sysutil.zig");
const SOCK = posix_constants.SOCK;

// Define a helper function
pub fn cStringTozigSttring(ptr: [*]const u8) usize {
    var index: usize = 0;
    while (ptr[index] != 0) : (index += 1) {}
    return index;
}

