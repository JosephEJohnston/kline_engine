const QuantContext = @import("../quant_context.zig").QuantContext;
const BacktestResult = @import("backtest_result.zig").BacktestResult;
const Flags = @import("../analyzer.zig").Flags;

/// 🌟 正式更名：Al Brooks M2B 策略回测
/// 逻辑：强趋势背景 + 触碰 EMA20 + 特定棒线形态
pub export fn run_al_brooks_m2b(
    ctx: *const QuantContext,
    initial_balance: f32
) BacktestResult {
    const count = ctx.count;
    if (count < 20) return BacktestResult.empty(); // 基础防御

    const closes = ctx.getCloseSlice();
    const attributes = ctx.attributes[0..count];

    var balance = initial_balance;
    var trade_count: u32 = 0;
    var win_count: u32 = 0;
    var in_position = false;
    var entry_price: f32 = 0;

    // 高速扫描循环
    for (1..count) |i| {
        const attr = attributes[i];

        if (!in_position) {
            // 1. 处于上升趋势中 (FLAG_TREND_UP)
            // 2. 并且由于你的 0x08 是 INSIDE，我们需要改用新的 TOUCH 位
            const is_setup = (attr & Flags.FLAG_TREND_UP) != 0;
            const is_touch = (attr & Flags.FLAG_TOUCH_EMA) != 0;

            // 如果是一根触碰均线的强阳线，且不是窄幅震荡的 Inside Bar
            if (is_setup and is_touch and (attr & Flags.FLAG_INSIDE == 0)) {
                in_position = true;
                entry_price = ctx.getClose(i);
                trade_count += 1;
            }
        } else {
            // 简单的出场逻辑实现 (1:2 风险报酬比)
            const pnl_pct = (closes[i] - entry_price) / entry_price;
            if (pnl_pct >= 0.02 or pnl_pct <= -0.01) {
                balance *= (1.0 + pnl_pct);
                if (pnl_pct > 0) win_count += 1;
                in_position = false;
            }
        }
    }

    return BacktestResult{
        .total_profit = (balance - initial_balance) / initial_balance,
        .win_rate = if (trade_count > 0) @as(f32, @floatFromInt(win_count)) / @as(f32, @floatFromInt(trade_count)) else 0,
        .trade_count = trade_count,
        .max_drawdown = 0, // 待后续实现
    };
}
