# Sort

This is a simple library with a Zig implementation of both the TimSort and PowerSort algorithms.

# Usage

To use this library, run the following command:

```bash
zig fetch --save git+https://github.com/max-legrand/sort#main
```

Then, in your `build.zig` add the following.

```build.zig
const sort = b.dependency("sort", .{});
exe_mod.addImport("sort", sort.module("sort"));
```

# Example

```zig
const std = @import("std");
const sort = @import("sort");

fn compare(a: i32, b: i32) i8 {
    if (a == b) return 0;
    if (a < b) return -1;
    return 1;
}

pub fn main() !void {
    var items = [_]i32{ 5, 2, 9, 1, 5, 6 };
    std.debug.print("Items: {any}\n", .{&items});
    try sort.powersort(i32, &items, compare);
    std.debug.print("Sorted items: {any}\n", .{&items});
}
```

# Testing

To run the tests you can run `zig build run` as all of the testing is handled in the main executable.
