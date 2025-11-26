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
        const wayland_dep = b.dependency("wayland", .{
            .target = target,
            .optimize = optimize,
        });
        const wayland_client = wayland_dep.artifact("wayland-client");
        const wayland_cursor = wayland_dep.artifact("wayland-cursor");

        rgfw_module.linkLibrary(wayland_client);
        rgfw_module.linkLibrary(wayland_cursor);
        rgfw_module.linkLibrary(wayland_client);

        const libxkbcommon_dependency = b.dependency("libxkbcommon", .{
            .target = target,
            .optimize = optimize,

            // Set the XKB config root.
            // Will default to "${INSTALL_PREFIX}/share/X11/xkb" i.e. `zig-out/share/X11/xkb`.
            // Most distributions will use `/usr/share/X11/xkb`.
            //
            // The value `""` will not set a default config root directory.
            // To configure the config root at runtime, use the "XKB_CONFIG_ROOT" environment variable.
            //
            // This example will assume that the config root of the host system is in `/usr`.
            // This does not work on distributions that don't follow the Filesystem Hierarchy Standard (FHS) like NixOS.
            .@"xkb-config-root" = "/usr/share/X11/xkb",

            // The X locale root.
            // Will default to "${INSTALL_PREFIX}/share/X11/locale" i.e. `zig-out/share/X11/locale`.
            // Most distributions will use `/usr/share/X11/locale`.
            //
            // To configure the config root at runtime, use the "XLOCALEDIR" environment variable.
            //
            // This example will assume that the config root of the host system is in `/usr`.
            // This does not work on distributions that don't follow the Filesystem Hierarchy Standard (FHS) like NixOS.
            .@"x-locale-root" = "/usr/share/X11/locale",
        });
        rgfw_module.linkLibrary(libxkbcommon_dependency.artifact("xkbcommon"));
    }

    const wayland_host = b.dependency("wayland", .{
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const wayland_scanner = wayland_host.artifact("wayland-scanner");

    const wayland_protocols_dep = b.dependency("wayland_protocols", .{
        .target = target,
        .optimize = optimize,
    });

    const xdg_headers = b.addWriteFiles();
    for ([_][]const u8{
        "stable/xdg-shell/xdg-shell.xml",
        "unstable/xdg-decoration/xdg-decoration-unstable-v1.xml",
        "unstable/pointer-constraints/pointer-constraints-unstable-v1.xml",
        "unstable/relative-pointer/relative-pointer-unstable-v1.xml",
        "unstable/xdg-output/xdg-output-unstable-v1.xml",
        "staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml",
    }) |path| {
        {
            const header_name = b.fmt("{s}.h", .{std.fs.path.stem(path)});
            const wayland_scanner_run = b.addRunArtifact(wayland_scanner);
            wayland_scanner_run.addArg("client-header");
            wayland_scanner_run.addFileArg(wayland_protocols_dep.path(path));
            _ = xdg_headers.addCopyFile(wayland_scanner_run.addOutputFileArg(header_name), header_name);
        }
        {
            const file_name = b.fmt("{s}.c", .{std.fs.path.stem(path)});
            const wayland_scanner_run = b.addRunArtifact(wayland_scanner);
            wayland_scanner_run.addArg("private-code");
            wayland_scanner_run.addFileArg(wayland_protocols_dep.path(path));
            rgfw_module.addCSourceFile(.{ .file = wayland_scanner_run.addOutputFileArg(file_name) });
        }
    }
    rgfw_module.addIncludePath(xdg_headers.getDirectory());

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
        translate_c.addIncludePath(xdg_headers.getDirectory());
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
