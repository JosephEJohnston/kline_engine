const std = @import("std");

pub fn build(b: *std.Build) void {

    const navtive_target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const mod = makeMod(b, &navtive_target);

    const exe = makeExe(b, &navtive_target, &optimize, mod);

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const wasm = makeWasm(b, &optimize);

    // 安装 wasm 的步骤（输出到 Next.js 目录）
    const install_wasm = b.addInstallArtifact(wasm, .{
        .dest_dir = .{ .override = .{ .custom = "../kline-next/public/wasm" } },
    });
    const wasm_step = b.step("wasm", "编译 WASM 模块");
    wasm_step.dependOn(&install_wasm.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

}

fn makeWasm(
    b: *std.Build,
    optimize: *const std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    const wasm = b.addExecutable(.{
        .name = "kline_engine",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"), // WASM 导出逻辑在 root.zig
            .target = wasm_target,
            .optimize = optimize.*,
        })
    });

    // WASM 特有配置
    wasm.entry = .disabled;
    wasm.rdynamic = true;

    return wasm;
}

fn makeMod(
    b: *std.Build,
    target: *const std.Build.ResolvedTarget
) *std.Build.Module {
    return b.addModule("kline_engine", .{

        .root_source_file = b.path("src/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target.*,
    });
}

fn makeExe(
    b: *std.Build,
    target: *const std.Build.ResolvedTarget,
    optimize: *const std.builtin.OptimizeMode,
    mod: *std.Build.Module
) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = "kline_engine",
        .root_module = b.createModule(.{

            .root_source_file = b.path("src/main.zig"),

            .target = target.*,
            .optimize = optimize.*,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                .{ .name = "kline_engine", .module = mod },
            },
        }),
    });
}
