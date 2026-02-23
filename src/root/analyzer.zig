const std = @import("std");
const QuantContext = @import("quant_context.zig").QuantContext;

// 定义属性标志位
pub const Flags = struct {
    pub const FLAG_TREND_UP:   u8 = 0b00000001;
    pub const FLAG_TREND_DOWN: u8 = 0b00000010;
    pub const FLAG_DOJI:       u8 = 0b00000100;
    pub const FLAG_INSIDE:     u8 = 0b00001000;

    pub const FLAG_TOUCH_EMA:  u8 = 0b00010000; // 16: 触碰 EMA20
    pub const FLAG_GAP_BAR:    u8 = 0b00100000; // 32: 缺口棒 (与均线完全脱离)
};

pub const PA_Extractors = struct {
    // 1. 强阳线算子
    pub const TrendUp = struct {
        pub const flag = Flags.FLAG_TREND_UP;
        pub fn check(o: anytype, c: anytype, _: anytype, _: anytype, _: anytype) @TypeOf(o > c) {
            return c > o; // 基础逻辑，可后续加入实体比例判断
        }
    };

    // 2. 强阴线算子
    pub const TrendDown = struct {
        pub const flag = Flags.FLAG_TREND_DOWN;
        pub fn check(o: anytype, c: anytype, _: anytype, _: anytype, _: anytype) @TypeOf(o > c) {
            return c < o;
        }
    };

    // 3. 十字星算子 (Al Brooks: 实体极小或无实体)
    pub const Doji = struct {
        pub const flag = Flags.FLAG_DOJI;
        pub fn check(o: anytype, c: anytype, h: anytype, l: anytype, _: anytype) @TypeOf(o > c) {
            const body = if (@TypeOf(o) == f32) @abs(c - o) else @abs(c - o);
            const range = h - l;
            const threshold = if (@TypeOf(o) == f32) 0.1 else @as(@TypeOf(o), @splat(0.1));
            // 实体小于全长的 10% 视为 Doji
            return body < (range * threshold);
        }
    };

    // 4. 触碰均线算子
    pub const TouchEMA = struct {
        pub const flag = Flags.FLAG_TOUCH_EMA;
        pub fn check(_: anytype, _: anytype, h: anytype, l: anytype, ema: anytype) @TypeOf(h > l) {
            return (l <= ema) & (h >= ema);
        }
    };

    // 5. 缺口棒算子 (完全脱离均线)
    pub const GapBar = struct {
        pub const flag = Flags.FLAG_GAP_BAR;
        pub fn check(_: anytype, _: anytype, h: anytype, l: anytype, ema: anytype) @TypeOf(h > l) {
            return (l > ema) | (h < ema);
        }
    };
};

pub fn extract_inside_bars(ctx: *QuantContext) void {
    const count = ctx.count;
    // 如果不足两根，物理上不可能存在 Inside Bar
    if (count < 2) return;

    var i: usize = 1;

    const Vec4f = @Vector(4, f32);
    const Vec4u = @Vector(4, u8);

    // --- 1. SIMD 主大路 (128-bit 向量化) ---
    // 每次处理 4 根，直到剩余不足 4 根为止
    while (i + 4 <= count) : (i += 4) {
        const v_h: Vec4f = ctx.highs[i..][0..4].*;
        const v_l: Vec4f = ctx.lows[i..][0..4].*;
        // 关键点：i-1 实现了跨棒线读取
        const v_ph: Vec4f = ctx.highs[i - 1 ..][0..4].*;
        const v_pl: Vec4f = ctx.lows[i - 1 ..][0..4].*;

        // 计算掩码：当前高 <= 前高 AND 当前低 >= 前低
        const mask = (v_h <= v_ph) & (v_l >= v_pl);

        // 🌟 必须先加载原有属性，以免覆盖掉之前的 FLAG_TREND 等标签
        var v_attr: Vec4u = ctx.attributes[i..][0..4].*;
        v_attr |= @select(u8, mask, @as(Vec4u, @splat(Flags.FLAG_INSIDE)), @as(Vec4u, @splat(0)));

        // 写回内存
        ctx.attributes[i..][0..4].* = v_attr;
    }

    // --- 2. 🌟 尾部处理 (Scalar Tail Handling) ---
    // 处理剩余的 j 根数据 (j 属于 [0, 3])
    // 这里的 i 已经停在最后一个 4 倍数对齐的位置
    for (i..count) |j| {
        // 标量逻辑：简单、直接、稳健
        if (ctx.highs[j] <= ctx.highs[j - 1] and ctx.lows[j] >= ctx.lows[j - 1]) {
            ctx.attributes[j] |= Flags.FLAG_INSIDE;
        }
    }
}

pub fn extract_attributes_universal(
    ctx: *QuantContext,
    comptime extractors: anytype // 接收如 .{TrendExtractor, DojiExtractor}
) void {
    const Vec4f = @Vector(4, f32);
    const Vec4u = @Vector(4, u8);

    const count = ctx.count;
    var i: usize = 0;

    // 🌟 核心：一次搬运，多次计算
    while (i + 4 <= count) : (i += 4) {
        // 1. 批量加载到寄存器 (SIMD Load)
        const v_o: Vec4f = ctx.opens[i..][0..4].*;
        const v_h: Vec4f = ctx.highs[i..][0..4].*;
        const v_l: Vec4f = ctx.lows[i..][0..4].*;
        const v_c: Vec4f = ctx.closes[i..][0..4].*;

        var v_attr: Vec4u = @splat(0);

        // 2. 编译时静态展开 (Zero Overhead)
        inline for (extractors) |Extractor| {
            const mask = Extractor.check(v_o, v_c, v_h, v_l);
            // 使用 @select 批量打标
            v_attr |= @select(
                u8,
                mask,
                @as(Vec4u, @splat(Extractor.flag)),
                @as(Vec4u, @splat(0))
            );
        }

        // 3. 一次性写回内存
        ctx.attributes[i..][0..4].* = v_attr;
    }

    // --- 2. 🌟 通用化尾部处理 ---
        // 利用同样的 inline for，但这次传入的是标量数据
    for (i..count) |j| {
        var attr: u8 = 0;
        inline for (extractors) |Extractor| {
            // 这里 check 会自动生成标量版的机器码
            if (Extractor.check(ctx.opens[j], ctx.closes[j], ctx.highs[j], ctx.lows[j])) {
                attr |= Extractor.flag;
            }
        }
        ctx.attributes[j] = attr;
    }
}

