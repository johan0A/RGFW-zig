const std = @import("std");

pub fn main() !void {
    var gpa_impl: std.heap.DebugAllocator(.{}) = .init;
    const gpa = gpa_impl.allocator();

    const args = try std.process.argsAlloc(gpa);

    const input_path = args[1];
    const output_path = args[2];

    const input_file = try std.fs.cwd().openFile(input_path, .{});
    const content = try input_file.readToEndAlloc(gpa, std.math.maxInt(usize));
    const result = try std.mem.replaceOwned(u8, gpa, content, " export ", " ");
    const output_file = try std.fs.cwd().createFile(output_path, .{});
    try output_file.writeAll(result);
}
