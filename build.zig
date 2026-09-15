const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zarko_mod = b.addModule("zarko", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zarko_tests = b.addTest(.{
        .root_module = zarko_mod,
    });
    const run_mod_tests = b.addRunArtifact(zarko_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_mod_tests.step);

    const parser = b.addModule("parser", .{
        .root_source_file = b.path("examples/parser.zig"),
        .target = target,
        .optimize = optimize,
    });

    const parser_exe = b.addExecutable(.{
        .name = "parser",
        .root_module = parser,
    });
    parser_exe.root_module.addImport("zarko", zarko_mod);

    const run_parser = b.step(
        "run-parser",
        "Run the parser example",
    );

    const run_parser_cmd = b.addRunArtifact(parser_exe);
    run_parser.dependOn(&run_parser_cmd.step);

    const file_parser = b.addModule("file_parser", .{
        .root_source_file = b.path("examples/file_parser.zig"),
        .target = target,
        .optimize = optimize,
    });

    const file_parser_exe = b.addExecutable(.{
        .name = "file_parser",
        .root_module = file_parser,
    });
    file_parser_exe.root_module.addImport("zarko", zarko_mod);

    const run_file_parser = b.step(
        "run-file-parser",
        "Run the file parser example",
    );

    const run_file_parser_cmd = b.addRunArtifact(file_parser_exe);
    run_file_parser.dependOn(&run_file_parser_cmd.step);

    const file_writer = b.addModule("file_writer", .{
        .root_source_file = b.path("examples/file_writer.zig"),
        .target = target,
        .optimize = optimize,
    });

    const file_writer_exe = b.addExecutable(.{
        .name = "file_writer",
        .root_module = file_writer,
    });
    file_writer_exe.root_module.addImport("zarko", zarko_mod);

    const run_file_writer = b.step(
        "run-file-writer",
        "Run the file writer example",
    );

    const run_file_writer_cmd = b.addRunArtifact(file_writer_exe);
    run_file_writer.dependOn(&run_file_writer_cmd.step);
}
