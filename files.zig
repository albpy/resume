
const std = @import("std");
const utils = @import("utils.zig");
//const get_path =  @import("get_path.zig");

const files = @cImport
    (
        {
            @cInclude("c_utils.c");
            @cInclude("stdio.h");
        }
    );

pub fn read_file_names() [*c][*c]u8 {
    const path :[*c]const u8 = "home/albin/Downloads/zig-linux-x86_64-0.14.0-dev.185+c40708a2c/workflow_chatbot";
    const num_files = files.count_files(path);
    const filenames : [*c][*c]u8 = files.get_file_names(path, num_files);
    return filenames;
}
