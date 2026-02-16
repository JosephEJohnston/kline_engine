const std = @import("std");
const kline_engine = @import("kline_engine");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    try kline_engine.bufferedPrint();
}
