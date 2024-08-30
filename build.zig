
const std = @import("std");
const Builder = std.Build;


pub fn build(b: *Builder) void {
    const mode = b.standardOptimizeOption(.{});

    const main_exe = b.addExecutable(.{
        .name = "zig_chat_bot",
        .root_source_file = b.path("main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = mode,
    });

    // Add include path for C source files
//    main_exe.addIncludePath(.{.path=".",});

    // Link against libc
    main_exe.linkLibC();

    const run_cmd = b.addRunArtifact(main_exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step); 
}
