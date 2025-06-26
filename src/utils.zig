const std = @import("std");

pub fn insertionSort(comptime T: type, list: []T, compare: fn (a: T, b: T) i8) void {
    var idx: usize = 1;
    while (idx < list.len) : (idx += 1) {
        var i = idx;
        var jdx: usize = idx - 1;
        while (jdx >= 0) {
            if (compare(list[i], list[jdx]) < 0) {
                const tmp = list[i];
                list[i] = list[jdx];
                list[jdx] = tmp;
                i = jdx;
            }
            if (jdx == 0) {
                break;
            }
            jdx -= 1;
        }
    }
}

pub fn isSorted(comptime T: type, list: []T, compare: fn (a: T, b: T) i8) bool {
    var i: usize = 1;
    while (i < list.len) : (i += 1) {
        if (compare(list[i - 1], list[i]) == 1) {
            return false;
        }
    }
    return true;
}
