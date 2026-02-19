const std = @import("std");
const builtin = @import("builtin");

// 只有在 WASM 环境下才真正链接这些 extern 函数
pub const is_wasm = builtin.target.cpu.arch == .wasm32;

// 原始导入
const imports = struct {
    extern fn js_log_err(ptr: [*]const u8, len: usize) void;
    // 以后可以在这里加更多：js_on_trade(), js_on_complete() 等
};

// 写一个包装函数，方便调用
pub fn logDebug(comptime fmt: []const u8, args: anytype) void {
    if (builtin.mode == .Debug) {
            // 如果是 WASM，调用 JS 函数
        if (is_wasm) {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
            imports.js_log_err(msg.ptr, msg.len);
        } else {
            // 如果是本地 Native 环境，直接打印到终端
            std.debug.print(fmt, args);
            std.debug.print("\n", .{});
        }
    }
}
