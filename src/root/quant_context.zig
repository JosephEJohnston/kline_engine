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

    // 2. 元数据与内存管理
    count: usize,
    capacity: usize,
    allocator: std.mem.Allocator,

    // 3. 🌟 通用指标池
    indicators: std.StringArrayHashMap([]f32),

    /// 注册并分配一个新的指标空间 (如 "ema20")
    /// 返回分配好的切片，供计算逻辑直接写入
    pub fn registerIndicator(self: *QuantContext, name: []const u8) ![]f32 {
        // 如果已存在则直接返回
        if (self.indicators.get(name)) |existing| return existing;

        // 为新指标分配与 K 线数量等长的内存
        const buffer = try self.allocator.alloc(f32, self.count);
        @memset(buffer, 0);

        try self.indicators.put(name, buffer);
        return buffer;
    }

    /// 获取指标切片
    pub fn getIndicator(self: *const QuantContext, name: []const u8) ?[]f32 {
        return self.indicators.get(name);
    }

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

    pub inline fn receiveBar(self: *QuantContext, index: usize, bar: Bar) void {
        // 安全起见，这里可以加个断言，毕竟你现在是精准申请内存
        std.debug.assert(index < self.count);

        self.time[index] = bar.time;
        self.open[index] = bar.open;
        self.high[index] = bar.high;
        self.low[index] = bar.low;
        self.close[index] = bar.close;
        self.volume[index] = bar.volume;
    }

    // --- 1. 单点读取 (Single Element Getters) ---
    // 适合在 UI 渲染或编写单根 K 线逻辑时使用

    pub inline fn getOpen(self: QuantContext, index: usize) f32 {
        std.debug.assert(index < self.count);
        return self.open[index];
    }

    pub inline fn getHigh(self: QuantContext, index: usize) f32 {
        std.debug.assert(index < self.count);
        return self.high[index];
    }

    pub inline fn getLow(self: QuantContext, index: usize) f32 {
        std.debug.assert(index < self.count);
        return self.low[index];
    }

    pub inline fn getClose(self: QuantContext, index: usize) f32 {
        std.debug.assert(index < self.count);
        return self.close[index];
    }

    pub inline fn getTime(self: QuantContext, index: usize) i64 {
        std.debug.assert(index < self.count);
        return self.time[index];
    }

    // --- 2. 切片读取 (Slice Getters) ---
    // 🌟 这才是量化引擎的“重型火力”。
    // 返回切片允许编译器进行 SIMD 优化，适合计算 EMA 或进行批量 PA 形态扫描。

    pub inline fn getOpenSlice(self: QuantContext) []f32 {
        return self.open[0..self.count];
    }

    pub inline fn getHighSlice(self: QuantContext) []f32 {
        return self.high[0..self.count];
    }

    pub inline fn getLowSlice(self: QuantContext) []f32 {
        return self.low[0..self.count];
    }

    pub inline fn getCloseSlice(self: QuantContext) []f32 {
        return self.close[0..self.count];
    }

    pub inline fn getTimeSlice(self: QuantContext) []i64 {
        return self.time[0..self.count];
    }
};

pub fn create_context(allocator: std.mem.Allocator, count: usize) !*QuantContext {
    // 1. 计算内存布局
    const time_size = count * @sizeOf(i64);
    const float_size = count * @sizeOf(f32);
    const attr_size = count * @sizeOf(u8);

    const total_bytes = time_size + (float_size * 5) + attr_size;

    // 2. 申请价格数据主内存
    const raw_mem = try allocator.alignedAlloc(
        u8,
        std.mem.Alignment.@"16",
        total_bytes
    );
    const base = raw_mem.ptr;

    // 3. 申请并初始化结构体
    const ctx = try allocator.create(QuantContext);

    // 初始化指标池（必须传入 allocator）
    ctx.indicators = std.StringArrayHashMap([]f32).init(allocator);
    ctx.allocator = allocator;

    // 4. 指针切分
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
