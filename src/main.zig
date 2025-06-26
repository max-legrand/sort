const std = @import("std");
const lib = @import("sort");

const string = []const u8;

fn printList(comptime T: type, list: []T) void {
    std.debug.print("[", .{});
    for (list, 0..) |item, idx| {
        if (idx > 0) {
            std.debug.print(",", .{});
        }
        std.debug.print("{d}", .{item});
    }
    std.debug.print("]\n", .{});
}

fn printStringList(list: []string) void {
    std.debug.print("[", .{});
    for (list, 0..) |item, idx| {
        if (idx > 0) std.debug.print(",", .{});
        std.debug.print("{s}", .{item});
    }
    std.debug.print("]\n", .{});
}

fn testList(comptime T: type, list: []T) void {
    if (!lib.isSorted(T, list, compareStrings)) {
        @panic("list not sorted");
    }
}

fn seedArray(comptime T: type, list: []T, rng: *std.Random.Xoshiro256, maxVal: T) void {
    var i: usize = 0;
    while (i < list.len) : (i += 1) {
        const value = rng.random().intRangeAtMost(T, 0, maxVal);
        list[i] = value;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const gpa_allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(gpa_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args_iter = std.process.args();
    var args = std.ArrayList(string).init(allocator);
    defer args.deinit();
    while (args_iter.next()) |arg| {
        try args.append(arg);
    }

    const cwd = std.fs.cwd();
    const testcases_dir = try cwd.openDir("testcases", .{ .iterate = true });

    if (args.items.len >= 2) {
        const file = try testcases_dir.openFile(args.items[1], .{ .mode = .read_only });
        defer file.close();
        try runFile(file, allocator, null);
        return;
    }

    // For each file in the testcases directory, parse the file
    // then sort it with timsort & powersort and compare.
    var walker = try testcases_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        const file = try testcases_dir.openFile(entry.path, .{ .mode = .read_only });
        defer file.close();

        try runFile(file, allocator, entry.path);
    }
}

fn compareStrings(a: string, b: string) i8 {
    if (std.mem.eql(u8, a, b)) {
        return 0;
    }
    const min_len = @min(a.len, b.len);
    for (0..min_len) |idx| {
        if (a[idx] < b[idx]) {
            return -1;
        } else if (a[idx] > b[idx]) {
            return 1;
        }
    }
    if (a.len < b.len) {
        return -1;
    }
    return 1;
}

fn runFile(file: std.fs.File, allocator: std.mem.Allocator, fileName: ?string) !void {
    const file_contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

    var iter = std.mem.splitScalar(u8, file_contents, '\n');
    var timsort_data = std.ArrayList(string).init(allocator);
    var powersort_data = std.ArrayList(string).init(allocator);
    while (iter.next()) |line| {
        if (line.len == 0) continue;
        const trimmed = std.mem.trimEnd(u8, line, "\r");
        try timsort_data.append(try allocator.dupe(u8, trimmed));
        try powersort_data.append(try allocator.dupe(u8, trimmed));
    }

    var start = std.time.nanoTimestamp();
    try lib.timsort(string, timsort_data.items, compareStrings);
    var delta = std.time.nanoTimestamp() - start;
    if (!lib.isSorted(string, timsort_data.items, compareStrings)) {
        if (fileName) |name| {
            const msg = std.fmt.allocPrint(allocator, "timsort: {s} => list not sorted", .{name}) catch unreachable;
            defer allocator.free(msg);
            printStringList(timsort_data.items);
            @panic(msg);
        } else {
            printStringList(timsort_data.items);
            @panic("timsort: list not sorted");
        }
    }
    if (fileName) |name| {
        std.debug.print("{s} => timsort: {d}ns\n", .{ name, delta });
    } else {
        std.debug.print("timsort: {d}ns\n", .{delta});
    }

    start = std.time.nanoTimestamp();
    try lib.powersort(string, powersort_data.items, compareStrings);
    delta = std.time.nanoTimestamp() - start;
    if (!lib.isSorted(string, powersort_data.items, compareStrings)) {
        if (fileName) |name| {
            const msg = std.fmt.allocPrint(allocator, "powersort: {s} => list not sorted", .{name}) catch unreachable;
            defer allocator.free(msg);
            printStringList(powersort_data.items);
            @panic(msg);
        } else {
            printStringList(powersort_data.items);
            @panic("powersort list not sorted");
        }
    }
    if (fileName) |name| {
        std.debug.print("{s} => powersort: {d}ns\n", .{ name, delta });
    } else {
        std.debug.print("powersort: {d}ns\n", .{delta});
    }
}
