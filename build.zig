const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const opengl = b.option(bool, "opengl", "enables opengl") orelse false;
    const wayland = b.option(bool, "wayland", "enables wayland") orelse false;
    const vulkan = b.option(bool, "vulkan", "enables vulkan") orelse false;

    const config_header = b.addConfigHeader(.{}, .{});
    if (opengl) config_header.addValue("RGFW_OPENGL", void, {});
    if (wayland) config_header.addValue("RGFW_WAYLAND", void, {});
    if (vulkan) config_header.addValue("RGFW_VULKAN", void, {});

    const rgfw_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    rgfw_module.addCSourceFile(.{
        .file = b.addWriteFiles().add("clay.c",
            \\#define RGFW_IMPLEMENTATION
            \\#include<config.h>
            \\#include<RGFW.h>
        ),
    });
    rgfw_module.addIncludePath(b.path("."));
    rgfw_module.addConfigHeader(config_header);

    const vulkan_headers_dep = b.dependency("vulkan_headers", .{});
    rgfw_module.addIncludePath(vulkan_headers_dep.path("include"));

    {
        const stub_mod = b.createModule(.{
            .root_source_file = b.path("src/stubs.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        const stub_lib = b.addLibrary(.{ .name = "stub", .root_module = stub_mod });
        rgfw_module.linkLibrary(stub_lib);

        const translate_c = b.addTranslateC(.{
            .root_source_file = b.addWriteFiles().add("stub.h",
                \\#define RGFW_IMPLEMENTATION
                \\#include<config.h>
                \\#include<RGFW.h>
            ),
            .target = target,
            .optimize = optimize,
        });
        translate_c.addIncludePath(b.path("."));
        translate_c.addIncludePath(b.path("include"));
        translate_c.addIncludePath(vulkan_headers_dep.path("include"));
        translate_c.addConfigHeader(config_header);

        const remove_exports = b.addExecutable(.{
            .name = "remove_exports",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/remove_exports_step.zig"),
                .target = b.graph.host,
                .optimize = .Debug,
            }),
        });
        const remove_exports_run = b.addRunArtifact(remove_exports);
        remove_exports_run.addFileArg(translate_c.getOutput());

        stub_mod.addImport("c", b.createModule(.{
            .root_source_file = remove_exports_run.addOutputFileArg("stub.zig"),
            .target = target,
            .optimize = optimize,
        }));
    }

    {
        const lib_rgfw = b.addLibrary(.{
            .name = "RGFW",
            .root_module = rgfw_module,
        });
        lib_rgfw.installConfigHeader(config_header);
        lib_rgfw.installHeader(b.path("RGFW.h"), "RGFW.h");
        b.installArtifact(lib_rgfw);
    }
}
