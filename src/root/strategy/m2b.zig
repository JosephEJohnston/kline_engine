const QuantContext = @import("../quant_context.zig").QuantContext;
const BacktestResult = @import("backtest_result.zig").BacktestResult;
const Flags = @import("../analyzer.zig").Flags;

// 🌟 正式更名：Al Brooks M2B 策略回测
// 逻辑：强趋势背景 + 触碰 EMA20 + 特定棒线形态
