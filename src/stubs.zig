const LibStub = struct {
    lib_name: [:0]const u8,
    functions: []const [:0]const u8,
};

const stubs: []const LibStub = &.{
    .{
        .lib_name = "libXrandr.so",
        .functions = &.{
            "XRRGetScreenInfo",
            "XRRGetScreenResources",
            "XRRGetCrtcInfo",
            "XRRConfigCurrentRate",
            "XRRGetOutputInfo",
            "XRRSetCrtcConfig",
            "XRRFreeOutputInfo",
            "XRRFreeCrtcInfo",
            "XRRFreeScreenResources",
            "XRRFreeScreenConfigInfo",
            "XRRGetScreenResourcesCurrent",
        },
    },
    .{
        .lib_name = "libX11.so",
        .functions = &.{
            "XInternAtom",
            "XGetSelectionOwner",
            "XConvertSelection",
            "XSync",
            "XNextEvent",
            "XGetWindowProperty",
            "XFree",
            "XDeleteProperty",
            "XGetWindowAttributes",
            "XStoreName",
            "XChangeProperty",
            "XMapWindow",
            "XUngrabPointer",
            "XFreeGC",
            "XDeleteContext",
            "XDestroyWindow",
            "XPending",
            "XEventsQueued",
            "XQueryPointer",
            "XWarpPointer",
            "XRaiseWindow",
            "XMapRaised",
            "XFlush",
            "XIconifyWindow",
            "XUnmapWindow",
            "XSetInputFocus",
            "XGetWMNormalHints",
            "XSetWMNormalHints",
            "XWidthOfScreen",
            "XHeightOfScreen",
            "XMoveWindow",
            "XResizeWindow",
            "XSetWMSizeHints",
            "XCreateImage",
            "XCreatePixmap",
            "XPutImage",
            "XSetWMHints",
            "XDefaultRootWindow",
            "XGrabPointer",
            "XkbKeycodeToKeysym",
            "XDefineCursor",
            "XInitThreads",
            "XOpenDisplay",
            "XrmUniqueQuark",
            "XCreateWindow",
            "XkbGetMap",
            "XSetErrorHandler",
            "XkbGetNames",
            "XkbGetKeyboardByName",
            "XkbFreeKeyboard",
            "XCloseDisplay",
            "XMatchVisualInfo",
            "XGetErrorText",
            "XCreateColormap",
            "XFreeColors",
            "XSaveContext",
            "XCreateGC",
            "XSetClassHint",
            "XSelectInput",
            "XSetWMProtocols",
            "XSetWindowBackground",
            "XClearWindow",
            "XSetWindowBackgroundPixmap",
            "XSendEvent",
            "XFreeEventData",
            "XGetEventData",
            "XFindContext",
            "XPeekEvent",
            "XkbGetState",
            "XTranslateCoordinates",
            "XCreateRegion",
            "XDestroyRegion",
            "XFreeCursor",
            "XCreateFontCursor",
            "XSetSelectionOwner",
            "XDisplayName",
            "XResourceManagerString",
            "XrmGetStringDatabase",
            "XrmGetResource",
            "XrmDestroyDatabase",
        },
    },
};

comptime {
    for (stubs) |stub| {
        for (stub.functions) |function_name| {
            @export(&makeFunctionStub(stub.lib_name, function_name), .{ .name = function_name });
        }
    }
}

fn makeFunctionStub(
    comptime lib_name: [:0]const u8,
    comptime func_name: [:0]const u8,
) @TypeOf(@field(c, func_name)) {
    const F = @TypeOf(@field(c, func_name));
    const f_info = @typeInfo(F).@"fn";

    const f = struct {
        fn f(args: std.meta.ArgsTuple(F)) (f_info.return_type orelse void) {
            if (@field(ptrs, func_name) == null) {
                if (@field(dlls, lib_name) == null) {
                    @field(dlls, lib_name) = std.c.dlopen(lib_name, .{ .LAZY = true });
                }

                if (@field(dlls, lib_name) == null) {
                    std.debug.panic("failure open {s} library at runtime", .{lib_name});
                }

                @field(ptrs, func_name) = @ptrCast(std.c.dlsym(@field(dlls, lib_name).?, func_name));
                if (@field(ptrs, func_name) == null) {
                    std.debug.panic("failure to link {s} function from {s} library at runtime", .{ func_name, lib_name });
                }
            }
            return @call(.auto, @field(ptrs, func_name).?, args);
        }
    }.f;

    return makeFn(f, f_info.calling_convention);
}

fn stub_Xrandr(comptime name: [:0]const u8, R: type, args: anytype) R {
    std.debug.print("{s}\n", .{name});

    if (@field(ptrs, name) == null) {
        if (dlls.xrandr == null) {
            dlls.xrandr = std.c.dlopen("libXrandr.so", .{ .LAZY = true });
        }

        @field(ptrs, name) = @ptrCast(std.c.dlsym(dlls.xrandr.?, name));
    }

    return @call(.auto, @field(ptrs, name).?, args);
}

const dlls = struct {
    var @"libXrandr.so": ?*anyopaque = null;
    var @"libX11.so": ?*anyopaque = null;
};

var ptrs: Ptrs = .{};

const Ptrs = blk: {
    var ptrs_info: std.builtin.Type.Struct = .{
        .layout = .auto,
        .fields = &.{},
        .decls = &.{},
        .is_tuple = false,
    };

    for (stubs) |stub| {
        for (stub.functions) |name| {
            const decl_type = @TypeOf(@field(c, name));
            const field_type = ?*decl_type;
            const default_value: field_type = null;
            ptrs_info.fields = ptrs_info.fields ++ &[_]std.builtin.Type.StructField{.{
                .name = name,
                .type = field_type,
                .default_value_ptr = @ptrCast(&default_value),
                .is_comptime = false,
                .alignment = @alignOf(field_type),
            }};
        }
    }

    break :blk @Type(.{ .@"struct" = ptrs_info });
};

// workaround for making functions with arbitrary count of arguments at comptime
fn makeFn(
    comptime func: anytype,
    comptime cc: std.builtin.CallingConvention,
) blk: {
    const func_info = @typeInfo(@TypeOf(func)).@"fn";
    var r_info: std.builtin.Type.Fn = .{
        .calling_convention = cc,
        .is_generic = false,
        .is_var_args = false,
        .return_type = func_info.return_type,
        .params = &.{},
    };
    const ArgsFields = @typeInfo(func_info.params[0].type.?).@"struct".fields;
    for (ArgsFields) |field| {
        r_info.params = r_info.params ++ [_]std.builtin.Type.Fn.Param{.{
            .is_generic = false,
            .is_noalias = false,
            .type = field.type,
        }};
    }
    break :blk @Type(.{ .@"fn" = r_info });
} {
    const func_info = @typeInfo(@TypeOf(func)).@"fn";
    comptime var Args: []const type = &.{};
    const ArgsFields = @typeInfo(func_info.params[0].type.?).@"struct".fields;
    for (ArgsFields) |field| {
        Args = Args ++ [_]type{field.type};
    }

    const Return = func_info.return_type orelse void;

    return switch (Args.len) {
        0 => struct {
            fn f() callconv(cc) Return {
                return @call(.always_inline, func, .{.{}});
            }
        }.f,
        1 => struct {
            fn f(a0: Args[0]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{a0}});
            }
        }.f,
        2 => struct {
            fn f(a0: Args[0], a1: Args[1]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1 }});
            }
        }.f,
        3 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2 }});
            }
        }.f,
        4 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3 }});
            }
        }.f,
        5 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4 }});
            }
        }.f,
        6 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4], a5: Args[5]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4, a5 }});
            }
        }.f,
        7 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4], a5: Args[5], a6: Args[6]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4, a5, a6 }});
            }
        }.f,
        8 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4], a5: Args[5], a6: Args[6], a7: Args[7]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4, a5, a6, a7 }});
            }
        }.f,
        9 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4], a5: Args[5], a6: Args[6], a7: Args[7], a8: Args[8]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4, a5, a6, a7, a8 }});
            }
        }.f,
        10 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4], a5: Args[5], a6: Args[6], a7: Args[7], a8: Args[8], a9: Args[9]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9 }});
            }
        }.f,
        11 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4], a5: Args[5], a6: Args[6], a7: Args[7], a8: Args[8], a9: Args[9], a10: Args[10]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 }});
            }
        }.f,
        12 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4], a5: Args[5], a6: Args[6], a7: Args[7], a8: Args[8], a9: Args[9], a10: Args[10], a11: Args[11]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 }});
            }
        }.f,
        13 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4], a5: Args[5], a6: Args[6], a7: Args[7], a8: Args[8], a9: Args[9], a10: Args[10], a11: Args[11], a12: Args[12]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 }});
            }
        }.f,
        14 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4], a5: Args[5], a6: Args[6], a7: Args[7], a8: Args[8], a9: Args[9], a10: Args[10], a11: Args[11], a12: Args[12], a13: Args[13]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13 }});
            }
        }.f,
        15 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4], a5: Args[5], a6: Args[6], a7: Args[7], a8: Args[8], a9: Args[9], a10: Args[10], a11: Args[11], a12: Args[12], a13: Args[13], a14: Args[14]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14 }});
            }
        }.f,
        16 => struct {
            fn f(a0: Args[0], a1: Args[1], a2: Args[2], a3: Args[3], a4: Args[4], a5: Args[5], a6: Args[6], a7: Args[7], a8: Args[8], a9: Args[9], a10: Args[10], a11: Args[11], a12: Args[12], a13: Args[13], a14: Args[14], a15: Args[15]) callconv(cc) Return {
                return @call(.always_inline, func, .{.{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15 }});
            }
        }.f,
        else => @compileError("too many arguments"),
    };
}

const c = @import("c");
const std = @import("std");
