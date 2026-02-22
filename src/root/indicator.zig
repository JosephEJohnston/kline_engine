const Bar = @import("bar.zig").Bar;
const QuantContext = @import("quant_context.zig").QuantContext;

pub fn calculate_ema(
    ctx: *const QuantContext, // 传入 context 引用
    period: usize,
    output_ptr: [*]f32
) void {
    // 1. 直接获取内部已有的 count 和价格切片
    const count = ctx.count;
    if (count < period) return;

    const closes = ctx.getCloseSlice(); // 🌟 利用你之前写的 slice getter
    const output = output_ptr[0..count];

    // 2. 预计算参数
    const alpha: f32 = 2.0 / @as(f32, @floatFromInt(period + 1));
    const one_minus_alpha = 1.0 - alpha;

    // 3. 计算第一个 EMA (SMA)
    var sum: f32 = 0;
    for (closes[0..period]) |val| {
        sum += val;
    }

    // 初始化填充
    for (0..period - 1) |i| {
        output[i] = 0; // 或者使用 std.math.nan(f32)
    }
    output[period - 1] = sum / @as(f32, @floatFromInt(period));

    // 4. 高效递归计算后续值
    // EMA_t = alpha * Price_t + (1 - alpha) * EMA_{t-1}
    var i: usize = period;
    while (i < count) : (i += 1) {
        output[i] = (alpha * closes[i]) + (one_minus_alpha * output[i - 1]);
    }
}
