const std = @import("std");

// 定义属性标志位
pub const Flags = struct {
    pub const FLAG_TREND_UP:   u8 = 0b00000001;
    pub const FLAG_TREND_DOWN: u8 = 0b00000010;
    pub const FLAG_DOJI:       u8 = 0b00000100;
    pub const FLAG_INSIDE:     u8 = 0b00001000;

    pub const FLAG_TOUCH_EMA:  u8 = 0b00010000; // 16: 触碰 EMA20
    pub const FLAG_GAP_BAR:    u8 = 0b00100000; // 32: 缺口棒 (与均线完全脱离)
};

pub fn extract_bar_attributes(
    opens: [*]const f32,
    highs: [*]const f32,
    lows: [*]const f32,
    closes: [*]const f32,
    len: usize,
    attr_ptr: [*]u8
) void {
    const attr = attr_ptr[0..len];

    var i: usize = 0;
    while (i < len) : (i += 1) {
        var flag: u8 = 0;
        const body_size = @abs(closes[i] - opens[i]);
        const total_range = highs[i] - lows[i];

        // 防止除以零
        const range_safe = if (total_range == 0) 0.00001
            else total_range;

        // 1. 识别趋势棒 (实体大于全长的 50%)
        if (body_size / range_safe > 0.5) {
            if (closes[i] > opens[i]) {
                flag |= Flags.FLAG_TREND_UP;
            } else {
                flag |= Flags.FLAG_TREND_DOWN;
            }
        }

        // 2. 识别十字星 (实体小于全长的 10%)
        if (body_size / range_safe < 0.1) {
            flag |= Flags.FLAG_DOJI;
        }

        // 3. 识别内包棒 (依赖前一根 K 线 n-1)
        if (i > 0) {
            if (highs[i] < highs[i-1] and lows[i] > lows[i-1]) {
                flag |= Flags.FLAG_INSIDE;
            }
        }

        attr[i] = flag;
    }
}
