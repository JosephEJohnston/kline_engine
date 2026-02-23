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

pub fn extract_ema_attributes(
    highs: []const f32,
    lows: []const f32,
    emas: []const f32,
    attributes: []u8,
) void {
    const Vec4f = @Vector(4, f32);
    const Vec4u = @Vector(4, u8);
    var i: usize = 0;

    // 🌟 SIMD 主循环：一次处理 4 根 K 线
    while (i + 4 <= highs.len) : (i += 4) {
        const v_h: Vec4f = highs[i..][0..4].*;
        const v_l: Vec4f = lows[i..][0..4].*;
        const v_e: Vec4f = emas[i..][0..4].*;

        // 1. 计算 TOUCH: (Low <= EMA) AND (High >= EMA)
        const touch_mask = (v_l <= v_e) & (v_h >= v_e);

        // 2. 计算 GAP: (Low > EMA) OR (High < EMA)
        const gap_mask = (v_l > v_e) | (v_h < v_e);

        // 3. 将布尔掩码转换为定义的 Bit Flags
        // 如果真则赋予对应的 Flag 值，否则为 0
        var v_attr: Vec4u = attributes[i..][0..4].*;

        v_attr |= @select(
            u8,
            touch_mask,
            @as(Vec4u, @splat(Flags.FLAG_TOUCH_EMA)),
            @as(Vec4u, @splat(0))
        );

        v_attr |= @select(
            u8,
            gap_mask,
            @as(Vec4u, @splat(Flags.FLAG_GAP_BAR)),
            @as(Vec4u, @splat(0))
        );

        // 写回内存
        attributes[i..][0..4].* = v_attr;
    }

    // 🌟 尾部处理：处理剩余不足 4 个的数据 (Tail Handling)
    for (i..highs.len) |j| {
        if (lows[j] <= emas[j] and highs[j] >= emas[j]) {
            attributes[j] |= Flags.FLAG_TOUCH_EMA;
        }
        if (lows[j] > emas[j] or highs[j] < emas[j]) {
            attributes[j] |= Flags.FLAG_GAP_BAR;
        }
    }
}
