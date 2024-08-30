
const std = @import("std");

const utils = @import("utils.zig");

const files = @import("files.zig");

pub fn main() void {
    const result = utils.add(5, 3);
    std.debug.print("The result is {d}\n", .{result});

    const filesFrompath = files.read_file_names();
    std.log.info("the files are : {s}", .{filesFrompath[0..4]});
}
