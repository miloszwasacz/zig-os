const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const Target = std.Target.x86;
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        // We use software float because we are disabling all SIMD stuff
        .cpu_features_add = Target.featureSet(&.{.soft_float}),
        // Disable all SIMD related stuff because SIMD are problematic in kernel
        .cpu_features_sub = Target.featureSet(&.{ .avx, .avx2, .sse, .sse2, .mmx }),
    });

    const libuart_compile = b.addSystemCommand(&[_][]const u8{ "cargo", "build", "--release" });
    libuart_compile.setCwd(b.path("uart16550"));

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = .kernel,
    });

    {
        const kernel = b.addExecutable(.{
            .name = "kernel.elf",
            .root_module = mod,
        });
        kernel.step.dependOn(&libuart_compile.step);
        kernel.addObjectFile(b.path("uart16550/target/target/release/libuart16550.a"));
        kernel.setLinkerScript(b.path("src/linker.ld"));
        b.installArtifact(kernel);

        const kernel_path = kernel.getEmittedBin();
        const qemu_cmd = b.addSystemCommand(&[_][]const u8{
            // zig fmt: off
            "qemu-system-x86_64",
            "-m", "1G",
            "-serial", "stdio",
            "-no-reboot",
            // zig fmt: on
        });
        qemu_cmd.addArg("-kernel");
        qemu_cmd.addFileArg(kernel_path);
        qemu_cmd.step.dependOn(b.getInstallStep());
        
        const run_step = b.step("run", "Run the kernel with QEMU");
        run_step.dependOn(&qemu_cmd.step);
    }
    {
        const tests = b.addTest(.{
            .root_module = mod,
            .test_runner = .{ 
                .path = b.path("src/testing.zig"), 
                .mode = .simple,
            },
        });
        tests.step.dependOn(&libuart_compile.step);
        tests.setLinkerScript(b.path("src/linker.ld"));
        b.installArtifact(tests);
        
        const runner_path = tests.getEmittedBin();
        const qemu_cmd = b.addSystemCommand(&[_][]const u8{
            // zig fmt: off
            "qemu-system-x86_64",
            "-m", "1G",
            "-serial", "stdio",
            "-display", "none",
            "-no-reboot",
            // zig fmt: on
        });
        qemu_cmd.addArg("-kernel");
        qemu_cmd.addFileArg(runner_path);
        qemu_cmd.step.dependOn(b.getInstallStep());
        
        const test_step = b.step("test", "Run tests with QEMU");
        test_step.dependOn(&qemu_cmd.step);
    }
}
