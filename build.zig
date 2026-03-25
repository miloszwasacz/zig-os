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

    const kernel = b.addExecutable(.{ .name = "kernel.elf", .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = .kernel,
    }) });
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

    // const run_cmd = b.addRunArtifact(kernel);
    // run_cmd.step.dependOn(&qemu_cmd.step);
    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }

    const run_step = b.step("run", "Run the kernel with QEMU");
    // run_step.dependOn(&run_cmd.step);
    run_step.dependOn(&qemu_cmd.step);

    // // Creates an executable that will run `test` blocks from the provided module.
    // // Here `mod` needs to define a target, which is why earlier we made sure to
    // // set the releative field.
    // const mod_tests = b.addTest(.{
    //     .root_module = mod,
    // });

    // // A run step that will run the test executable.
    // const run_mod_tests = b.addRunArtifact(mod_tests);

    // // Creates an executable that will run `test` blocks from the executable's
    // // root module. Note that test executables only test one module at a time,
    // // hence why we have to create two separate ones.
    // const exe_tests = b.addTest(.{
    //     .root_module = exe.root_module,
    // });

    // // A run step that will run the second test executable.
    // const run_exe_tests = b.addRunArtifact(exe_tests);

    // // A top level step for running all tests. dependOn can be called multiple
    // // times and since the two run steps do not depend on one another, this will
    // // make the two of them run in parallel.
    // const test_step = b.step("test", "Run tests");
    // test_step.dependOn(&run_mod_tests.step);
    // test_step.dependOn(&run_exe_tests.step);

    // // Just like flags, top level steps are also listed in the `--help` menu.
    // //
    // // The Zig build system is entirely implemented in userland, which means
    // // that it cannot hook into private compiler APIs. All compilation work
    // // orchestrated by the build system will result in other Zig compiler
    // // subcommands being invoked with the right flags defined. You can observe
    // // these invocations when one fails (or you pass a flag to increase
    // // verbosity) to validate assumptions and diagnose problems.
    // //
    // // Lastly, the Zig build system is relatively simple and self-contained,
    // // and reading its source code will allow you to master it.
}
