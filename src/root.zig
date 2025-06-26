const std = @import("std");
const utils = @import("utils.zig");
pub const isSorted = utils.isSorted;

const CHUNK_SIZE = 64;

fn minRunSize(comptime T: type, list: []T) usize {
    var n = list.len;
    var r: usize = 0;
    while (n >= CHUNK_SIZE) {
        r |= n & 1;
        n >>= 1;
    }
    const size = n + r;
    if (size < 32) {
        return 32;
    } else if (size > 64) {
        return 64;
    }
    return size;
}

const RunType = enum { Increasing, Decreasing, Neither };
fn extendRun(comptime T: type, list: []T, start: usize, minSize: usize, compare: fn (a: T, b: T) i8) usize {
    var i: usize = start;
    var direction: RunType = RunType.Neither;
    while (i < list.len) {
        if (i == start) {
            i += 1;
            continue;
        }

        if (compare(list[i - 1], list[i]) == -1 and (direction == RunType.Neither or direction == RunType.Increasing)) {
            direction = RunType.Increasing;
        } else if (compare(list[i - 1], list[i]) == 1 and (direction == RunType.Neither or direction == RunType.Decreasing)) {
            direction = RunType.Decreasing;
        } else {
            break;
        }
        i += 1;
    }

    // If the natural run is decreasing, we need to reverse it
    if (direction == RunType.Decreasing) {
        var left = start;
        var right = i - 1;
        while (left < right) {
            const tmp = list[left];
            list[left] = list[right];
            list[right] = tmp;
            left += 1;
            right -= 1;
        }
    }

    const len = i - start;
    if (len < minSize) {
        var diff = minSize - len;
        if (i + diff >= list.len) {
            diff = list.len - i;
        }
        // Insertion sort the run
        utils.insertionSort(T, list[start .. i + diff], compare);
        return i + diff;
    }
    return i;
}

const MergeType = enum { XY, YZ, Neither };
fn checkRules(comptime T: type, stack: *std.ArrayList([]T)) !MergeType {
    if (stack.items.len < 4) {
        return .Neither;
    }

    const z: []T = stack.pop().?;
    const y: []T = stack.pop().?;
    const x: []T = stack.pop().?;
    const w: []T = stack.pop().?;

    var return_value: MergeType = .Neither;
    if (z.len > x.len) {
        return_value = .XY;
    }
    if (z.len >= y.len) {
        return_value = .YZ;
    }
    if (y.len + z.len >= x.len) {
        return_value = .YZ;
    }
    if (x.len + y.len >= w.len) {
        return_value = .YZ;
    }
    try stack.append(w);
    try stack.append(x);
    try stack.append(y);
    try stack.append(z);
    return return_value;
}

const GALLOP_THRESHOLD = 7;

fn gallopRight(
    comptime T: type,
    x: []T,
    y_val: T,
    start: usize,
    end: usize,
    compare: fn (a: T, b: T) i8,
) usize {
    var low: usize = start;
    var high: usize = end;

    while (low < high) {
        const mid = (low + high) / 2;
        if (compare(x[mid], y_val) <= 0) {
            low = mid + 1;
        } else {
            high = mid;
        }
    }
    return low;
}

fn gallopLeft(
    comptime T: type,
    y: []T,
    x_val: T,
    start: usize,
    end: usize,
    compare: fn (a: T, b: T) i8,
) usize {
    var low: usize = start;
    var high: usize = end;
    while (low < high) {
        const mid = (low + high) / 2;
        if (compare(y[mid], x_val) <= 0) {
            low = mid + 1;
        } else {
            high = mid;
        }
    }
    return low;
}

fn merge(
    comptime T: type,
    x: []T,
    y: []T,
    allocator: std.mem.Allocator,
    compare: fn (a: T, b: T) i8,
) ![]T {
    const size = x.len + y.len;
    const result = try allocator.alloc(T, size);

    var i: usize = 0;
    var j: usize = 0;
    var k: usize = 0;

    var x_count: usize = 0;
    var y_count: usize = 0;

    while (i < x.len and j < y.len) {
        if (compare(x[i], y[j]) <= 0) {
            y_count = 0;
            x_count += 1;
            if (x_count >= GALLOP_THRESHOLD) {
                const gallop_end = gallopRight(T, x, y[j], i, x.len, compare);
                const n = gallop_end - i;
                for (0..n) |idx| {
                    result[k] = x[i + idx];
                    k += 1;
                }
                i = gallop_end;
                x_count = 0;
            } else {
                result[k] = x[i];
                i += 1;
                k += 1;
            }
        } else {
            x_count = 0;
            y_count += 1;
            if (y_count >= GALLOP_THRESHOLD) {
                const gallop_end = gallopLeft(T, y, x[i], j, y.len, compare);
                const n = gallop_end - j;
                for (0..n) |idx| {
                    result[k] = y[j + idx];
                    k += 1;
                }
                j = gallop_end;
                y_count = 0;
            } else {
                result[k] = y[j];
                j += 1;
                k += 1;
            }
        }
    }

    while (i < x.len) {
        result[k] = x[i];
        k += 1;
        i += 1;
    }
    while (j < y.len) {
        result[k] = y[j];
        k += 1;
        j += 1;
    }
    return result;
}

fn mergeRuns(
    comptime T: type,
    stack: *std.ArrayList([]T),
    mergeType: MergeType,
    allocator: std.mem.Allocator,
    compare: fn (a: T, b: T) i8,
) !void {
    switch (mergeType) {
        .XY => {
            const z: []T = stack.pop().?;
            const y: []T = stack.pop().?;
            const x: []T = stack.pop().?;
            // Merge x and y
            const merged = try merge(
                T,
                x,
                y,
                allocator,
                compare,
            );
            try stack.append(merged);
            try stack.append(z);
        },
        .YZ => {
            const z: []T = stack.pop().?;
            const y: []T = stack.pop().?;
            const merged = try merge(
                T,
                y,
                z,
                allocator,
                compare,
            );
            try stack.append(merged);
        },
        .Neither => unreachable,
    }
}

pub fn timsort(
    comptime T: type,
    list: []T,
    compare: fn (a: T, b: T) i8,
) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (list.len <= CHUNK_SIZE) {
        utils.insertionSort(T, list, compare);
        return;
    }

    var stack = std.ArrayList([]T).init(allocator);
    defer stack.deinit();

    const run_size: usize = minRunSize(T, list);

    var i: usize = 0;
    while (i < list.len) {
        const j = extendRun(T, list, i, run_size, compare);
        try stack.append(list[i..j]);
        var rulesCheck = try checkRules(T, &stack);
        while (rulesCheck != .Neither) {
            try mergeRuns(
                T,
                &stack,
                rulesCheck,
                allocator,
                compare,
            );
            rulesCheck = try checkRules(T, &stack);
        }
        i = j;
    }

    while (stack.items.len > 1) {
        try mergeRuns(
            T,
            &stack,
            .YZ,
            allocator,
            compare,
        );
    }

    if (stack.items.len == 1) {
        const sorted = stack.items[0];
        for (sorted, 0..) |item, idx| {
            list[idx] = item;
        }
    }

    return;
}

pub fn powersort(comptime T: type, list: []T, compare: fn (a: T, b: T) i8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (list.len <= CHUNK_SIZE) {
        utils.insertionSort(T, list, compare);
        return;
    }

    var stack = std.ArrayList([]T).init(allocator);
    defer stack.deinit();

    const run_size: usize = minRunSize(T, list);

    var i: usize = 0;
    while (i < list.len) {
        const j = extendRun(T, list, i, run_size, compare);
        try stack.append(list[i..j]);
        i = j;
    }

    const Run = struct {
        run: []T,
        power: usize,
    };

    const total_runs = stack.items.len;
    var powers = std.ArrayList(Run).init(allocator);
    defer powers.deinit();

    for (stack.items, 0..) |r, idx| {
        const power = @clz(idx ^ (total_runs - idx));
        try powers.append(.{
            .run = r,
            .power = power,
        });
    }

    while (powers.items.len > 1) {
        var min_power: usize = std.math.maxInt(usize);
        var a: usize = 0;
        var b: usize = 0;
        for (0..powers.items.len - 1) |idx| {
            const a_run = powers.items[idx];
            const b_run = powers.items[idx + 1];
            const sum = a_run.power + b_run.power;
            if (sum < min_power) {
                min_power = sum;
                a = idx;
                b = idx + 1;
            }
        }

        const a_run = powers.items[a].run;
        const b_run = powers.items[b].run;

        const value = try merge(T, a_run, b_run, allocator, compare);
        const minimum = @min(powers.items[a].power, powers.items[b].power);
        _ = powers.orderedRemove(b);
        powers.items[a].run = value;
        powers.items[a].power = minimum;
    }

    if (powers.items.len == 1) {
        const sorted = powers.items[0].run;
        for (sorted, 0..) |item, idx| {
            list[idx] = item;
        }
    }
}
