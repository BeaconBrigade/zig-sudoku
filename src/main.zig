const std = @import("std");

pub fn main() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var argv = std.process.argsWithAllocator(allocator) catch std.process.exit(123);
    defer argv.deinit();
    var args = AppArgs.parseFromArgs(&argv) catch |err| {
        switch (err) {
            ArgParseError.MissingInput, ArgParseError.UnknownArg => AppArgs.usage(),
            else => {},
        }
        std.process.exit(1);
    };
    args.debug();
}

const AppArgs = struct {
    inputPath: []const u8,
    outputPath: ?[]const u8,
    printPartials: bool,
    printDelay: ?u16,

    fn parseFromArgs(args: *std.process.ArgIterator) ArgParseError!AppArgs {
        _ = args.next().?;
        const inputPath = if (args.next()) |arg| arg else return ArgParseError.MissingInput;
        const outputPath = args.next();
        const printPartials = if (args.next()) |arg| std.ascii.toLower(arg[0]) == 'y' else false;
        const printDelay = if (args.next()) |arg| try std.fmt.parseInt(u16, arg, 10) else null;

        if (args.next()) |_| {
            return ArgParseError.UnknownArg;
        }

        return AppArgs{
            .printPartials = printPartials,
            .inputPath = inputPath,
            .outputPath = outputPath,
            .printDelay = printDelay,
        };
    }

    fn usage() void {
        std.debug.print(
            \\usage: zig-sudoku <input-path> [<output-path>] [<print-partials>] [<delay>]
            \\  input-path: path to sudoku puzzle
            \\  output-path: optional path to output solution. if unset, prints to stdout
            \\  print-partials (y/n): print incomplete solutions as they are tested
            \\  delay: wait between calculating each incomplete solution in milliseconds
            \\
        , .{});
    }

    fn debug(self: *const AppArgs) void {
        std.log.debug(
            \\AppArgs {{
            \\  inputPath: {s},
            \\  outputPath: {?s},
            \\  printPartials: {?},
            \\  printDelay: {?d}
            \\}}
        , .{ self.inputPath, self.outputPath, self.printPartials, self.printDelay });
    }
};

const ArgParseError = error{
    MissingInput,
    UnknownArg,
} || std.fmt.ParseIntError;
