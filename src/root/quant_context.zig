const std = @import("std");
const Bar = @import("bar.zig").Bar;

pub const QuantContext = struct {
    // 1. 原始价格数据 (SOA 布局)
    time: [*]i64,
    open: [*]f32,
    high: [*]f32,
    low: [*]f32,
    close: [*]f32,
    volume: [*]f32,

    // 2. 属性标记 (1 字节掩码)
    attributes: [*]u8,

    // 3. 元数据
    count: usize,
    capacity: usize,

    /// 核心方法：根据索引获取“虚拟”的 K 线视图
    /// 虽然内存是打散的，但逻辑上你还是可以像 Java 里的对象一样访问它
    pub fn getBar(self: QuantContext, index: usize) Bar {
        // 边界检查（养成好习惯，虽然 Zig 有安全检查）
        if (index >= self.count) unreachable;

            // 🌟 按需组装：从 SOA 布局中取出零散的字段，拼成一个 AOS 结构体返回
        return Bar{
                .time = self.time[index],
                .open = self.open[index],
                .high = self.high[index],
                .low = self.low[index],
                .close = self.close[index],
                .volume = self.volume[index],
            };
    }
};

pub fn create_context(allocator: std.mem.Allocator, count: usize) !*QuantContext {
    // 1. 计算各部分所需字节 (严格考虑对齐)
    const time_size = count * @sizeOf(i64);    // 8字节对齐
    const float_size = count * @sizeOf(f32);   // 4字节对齐
    const attr_size = count * @sizeOf(u8);     // 1字节对齐

    // 总布局：[Time] (8-byte align) | [Open] | [High] | [Low] | [Close] | [Vol] | [Attr]
    const total_bytes = time_size + (float_size * 5) + attr_size;

    // 2. 一次性申请整块内存
    const raw_mem = try allocator.alloc(u8, total_bytes);
    const base = raw_mem.ptr;

    // 3. 为结构体本身申请空间
    const ctx = try allocator.create(QuantContext);

    // 4. “切分”领地
    ctx.time = @ptrCast(@alignCast(base));
    ctx.open = @ptrCast(@alignCast(base + time_size));
    ctx.high = @ptrCast(@alignCast(base + time_size + float_size));
    ctx.low = @ptrCast(@alignCast(base + time_size + 2 * float_size));
    ctx.close = @ptrCast(@alignCast(base + time_size + 3 * float_size));
    ctx.volume = @ptrCast(@alignCast(base + time_size + 4 * float_size));
    ctx.attributes = @ptrCast(@alignCast(base + time_size + 5 * float_size));

    ctx.count = count;
    ctx.capacity = count;

    return ctx;
}
