const icon: [4 * 3 * 3]u8 = .{
    0xFF, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0xFF,
    0xFF, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0xFF, 0xFF, 0xFF, 0x00, 0xFF,
    0xFF, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0xFF,
};

fn clear(buffer: []u8, bufferWidth: i32, w: i32, h: i32, color: [4]u8) void {
    _ = w;

    if (color[0] == color[1] and color[0] == color[2] and color[0] == color[3]) {
        const size = @as(usize, @intCast(bufferWidth)) * @as(usize, @intCast(h)) * 4;
        @memset(buffer[0..size], color[0]);
        return;
    }

    const bw = @as(usize, @intCast(bufferWidth));
    const height = @as(usize, @intCast(h));

    for (0..height) |y| {
        for (0..bw) |x| {
            const index = y * 4 * bw + x * 4;
            buffer[index] = color[0];
            buffer[index + 1] = color[1];
            buffer[index + 2] = color[2];
            buffer[index + 3] = color[3];
        }
    }
}

fn drawBitmap(buffer: []u8, bufferWidth: i32, bitmap: []const u8, x: i32, y_pos: i32, w: i32, h: i32) void {
    const bw = @as(usize, @intCast(bufferWidth));
    const width = @as(usize, @intCast(w));
    const height = @as(usize, @intCast(h));
    const startX = @as(usize, @intCast(x));
    const startY = @as(usize, @intCast(y_pos));

    for (0..height) |y| {
        const destIndex = (y + startY) * 4 * bw + startX * 4;
        const srcIndex = y * 4 * width;
        const copySize = width * 4;
        @memcpy(buffer[destIndex .. destIndex + copySize], bitmap[srcIndex .. srcIndex + copySize]);
    }
}

fn drawRect(buffer: []u8, bufferWidth: i32, rectX: i32, rectY: i32, w: i32, h: i32, color: [4]u8) void {
    const bw = @as(usize, @intCast(bufferWidth));
    const x1 = @as(usize, @intCast(rectX));
    const y1 = @as(usize, @intCast(rectY));
    const width = @as(usize, @intCast(w));
    const height = @as(usize, @intCast(h));

    for (x1..x1 + width) |x| {
        for (y1..y1 + height) |y| {
            const index = y * 4 * bw + x * 4;
            buffer[index] = color[0];
            buffer[index + 1] = color[1];
            buffer[index + 2] = color[2];
            buffer[index + 3] = color[3];
        }
    }
}

pub fn main() !void {
    const win = c.RGFW_createWindow("Basic buffer example", 0, 0, 500, 500, c.RGFW_windowCenter | c.RGFW_windowTransparent);
    defer c.RGFW_window_close(win);

    c.RGFW_window_setExitKey(win, c.RGFW_escape);

    const mon = c.RGFW_window_getMonitor(win);

    // Wayland workaround if needed:
    // mon.mode.w = 500;
    // mon.mode.h = 500;

    const allocator = std.heap.page_allocator;
    const bufferSize = @as(usize, @intCast(mon.mode.w)) * @as(usize, @intCast(mon.mode.h)) * 4;
    const buffer = try allocator.alloc(u8, bufferSize);
    defer allocator.free(buffer);

    const surface = c.RGFW_createSurface(buffer.ptr, mon.mode.w, mon.mode.h, c.RGFW_formatRGBA8);
    defer c.RGFW_surface_free(surface);

    var running = true;

    while (running) {
        var event: c.RGFW_event = undefined;
        while (c.RGFW_window_checkEvent(win, &event) == c.RGFW_TRUE) {
            if (event.type == c.RGFW_quit or c.RGFW_window_isKeyPressed(win, c.RGFW_escape) == c.RGFW_TRUE) {
                running = false;
                break;
            }
        }

        const color = [4]u8{ 0, 0, 255, 125 };
        const color2 = [4]u8{ 255, 0, 0, 255 };

        var w: i32 = undefined;
        var h: i32 = undefined;
        _ = c.RGFW_window_getSize(win, &w, &h);

        clear(buffer, mon.mode.w, w, h, color);
        drawRect(buffer, mon.mode.w, 200, 200, 200, 200, color2);
        drawBitmap(buffer, mon.mode.w, &icon, 100, 100, 3, 3);

        c.RGFW_window_blitSurface(win, surface);
    }
}
const std = @import("std");
const c = @import("c");
