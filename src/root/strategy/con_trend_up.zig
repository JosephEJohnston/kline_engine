const QuantContext = @import("../quant_context.zig").QuantContext;
const BacktestResult = @import("backtest_result.zig").BacktestResult;
const Flags = @import("../analyzer.zig").Flags;

pub fn consecutive_trend_up(
    ctx: *QuantContext,
    comptime n: usize
) BacktestResult {
    var result = BacktestResult{};
    var up_count: usize = 0;
    var current_max_profit: f32 = 0.0;
    var running_equity: f32 = 0.0;

    for (0..ctx.count) |i| {
        const attr = ctx.attributes[i];

        // 1. 识别逻辑：是否符合 FLAG_TREND_UP
        if ((attr & Flags.FLAG_TREND_UP) != 0) {
            up_count += 1;
        } else {
            up_count = 0;
        }

        // 2. 信号触发：当达到连续 N 根时
        // 注意：i+1 不能越界，因为我们要看下一根的表现
        if (up_count >= n and i + 1 < ctx.count) {
            result.total_trades += 1;

            // 假设逻辑：下根开盘买入，收盘卖出
            const entry_price = ctx.open[i + 1];
            const exit_price = ctx.close[i + 1];
            const profit = exit_price - entry_price;

            result.total_profit += profit;
            if (profit > 0) result.win_count += 1;

            // 3. 简单的回撤计算逻辑
            running_equity += profit;
            if (running_equity > current_max_profit) {
                current_max_profit = running_equity;
            }
            const dd = current_max_profit - running_equity;
            if (dd > result.max_drawdown) {
                result.max_drawdown = dd;
            }

            // 避免在同一串阳线中重复触发，重置计数器
            // 这样如果你设 N=3，第 3 根触发后，第 4 根重新开始算
            up_count = 0;
        }
    }

    return result;
}
