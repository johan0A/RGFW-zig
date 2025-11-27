const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    {
        const rgfw_dep = b.dependency("RGFW", .{
            .target = target,
            .optimize = optimize,
            // .wayland = true,
            // .vulkan = true,
        });
        const rgfw_lib = rgfw_dep.artifact("RGFW");
        root_mod.linkLibrary(rgfw_lib);

        const translate_c = b.addTranslateC(.{
            .root_source_file = b.addWriteFiles().add("stub.h", "#include<RGFW.h>"),
            .target = target,
            .optimize = optimize,
        });
        translate_c.addIncludePath(rgfw_lib.getEmittedIncludeTree());
        root_mod.addImport("c", translate_c.createModule());
    }

    {
        const exe = b.addExecutable(.{ .name = "zclay-example", .root_module = root_mod });
        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}
