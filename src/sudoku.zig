const std = @import("std");
const root = @import("root");

pub const Solution = struct {
    root: Node,
    args: root.AppArgs,
    solution: ?*Node,

    pub fn init(args: root.AppArgs, allocator: *std.mem.Allocator) !Solution {
        var puzzle = try parsePuzzle(args.inputPath, allocator);
        var rootNode = Node.init(puzzle);
        return Solution{
            .root = rootNode,
            .args = args,
            .solution = null,
        };
    }

    pub fn solve(self: *Solution, allocator: *std.mem.Allocator) !void {
        if (try self.root.backtrack(allocator)) |solution| {
            self.solution = solution;
        } else {
            return error.Unsolvable;
        }
    }

    pub fn printSolution(self: *Solution) !void {
        if (self.solution) |solution| {
            try printPuzzle(&solution.puzzle);
        } else {
            return error.NotSolved;
        }
    }
};

const Node = struct {
    puzzle: []u8,
    children: [9]?*Node,
    childIndex: usize,

    fn init(puzzle: []u8) Node {
        return Node{
            .puzzle = puzzle,
            .children = [1]?*Node{null} ** 9,
            .childIndex = 0,
        };
    }

    fn backtrack(self: *Node, allocator: *std.mem.Allocator) !?*Node {
        // base cases
        if (!self.isValid()) {
            std.log.debug("invalid", .{});
            return null;
        } else if (self.isComplete()) {
            std.log.debug("complete", .{});
            return self;
        }

        var toChange = try self.first(allocator);
        var nextPtr: ?*Node = self.children[self.childIndex];

        while (nextPtr) |childPtr| {
            if (try childPtr.backtrack(allocator)) |solution| {
                std.log.debug("solution found", .{});
                return solution;
            }

            if (try self.next(toChange, allocator)) |_| {
                nextPtr = self.children[self.childIndex];
            } else {
                break;
            }
        }

        std.log.debug("no children solutions found", .{});
        return null;
    }

    fn first(self: *Node, allocator: *std.mem.Allocator) !u32 {
        var childPtr = try allocator.create(Node);
        var buf = try allocator.alloc(u8, 81);
        std.mem.copy(u8, buf[0..81], self.puzzle[0..81]);
        childPtr.* = Node{
            .puzzle = buf,
            .children = [1]?*Node{null} ** 9,
            .childIndex = 0,
        };

        var toChange: u32 = undefined;
        for (self.puzzle) |slot, i| {
            if (slot == 0) {
                toChange = @intCast(u32, i);
            }
        }

        childPtr.puzzle[toChange] = 1;
        self.children[self.childIndex] = childPtr;

        return toChange;
    }

    fn next(self: *Node, toChange: usize, allocator: *std.mem.Allocator) !?void {
        if (self.childIndex >= 8) {
            return null;
        }

        var prev = self.children[self.childIndex].?;

        var childPtr = try allocator.create(Node);
        var buf = try allocator.alloc(u8, 81);
        std.mem.copy(u8, buf[0..81], prev.puzzle[0..81]);
        childPtr.* = Node{
            .puzzle = buf,
            .children = [1]?*Node{null} ** 9,
            .childIndex = 0,
        };
        childPtr.puzzle[toChange] += 1;

        self.childIndex += 1;
        self.children[self.childIndex] = childPtr;

        return undefined;
    }

    fn isComplete(self: *Node) bool {
        for (self.puzzle) |slot| {
            if (slot == 0) {
                return false;
            }
        }
        return true;
    }

    fn isValid(self: *Node) bool {
        var matches = [11]u32{ 69, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255 };

        // check horizontal rows
        for (range(9)) |_, i| {
            for (range(9)) |_, j| {
                matches[self.puzzle[i * 9 + j]] += 1;
            }

            if (occursMultiple(&matches)) {
                std.log.debug("failed horizontally", .{});
                return false;
            }
        }

        // check vertical rows
        for (range(9)) |_, i| {
            for (range(9)) |_, j| {
                matches[self.puzzle[j * 9 + i]] += 1;
            }

            if (occursMultiple(&matches)) {
                std.log.debug("failed vertically", .{});
                return false;
            }
        }

        // check squares
        for (range(3)) |_, i| {
            // rows
            for (range(3)) |_, j| {
                var offset = (i * 27) + (j * 3);
                // columns
                for (range(3)) |_, k| {
                    matches[self.puzzle[offset + k * 9]] += 1;
                    matches[self.puzzle[offset + k * 9 + 1]] += 1;
                    matches[self.puzzle[offset + k * 9 + 2]] += 1;
                }
            }

            if (occursMultiple(&matches)) {
                std.log.debug("failed squarily(?)", .{});
                return false;
            }
        }

        return true;
    }
};

fn occursMultiple(matches: *[11]u32) bool {
    for (matches[1..10]) |val, i| {
        std.log.debug("val {d}: {d}", .{i, val});
        if (val > 1) {
            return true;
        }

        matches[i+1] = 0;
    }
    return false;
}

fn parsePuzzle(path: []const u8, allocator: *std.mem.Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const fileSize = (try file.stat()).size;
    var buf = try allocator.alloc(u8, fileSize);
    defer allocator.destroy(&buf);

    const bytesRead = try file.readAll(buf);
    if (bytesRead < 81) {
        std.log.err("puzzle not long enough: {d} bytes", .{bytesRead});
        return error.TooShort;
    }

    var puzzle: []u8 = try allocator.alloc(u8, 81);
    var i: u32 = 0;

    for (buf) |byte| {
        if (std.ascii.isWhitespace(byte)) {
            continue;
        }

        if (std.ascii.isDigit(byte)) {
            puzzle[i] = std.fmt.parseInt(u8, &[1]u8{byte}, 10) catch unreachable;
        } else {
            puzzle[i] = 0;
        }

        i += 1;

        if (i == 81) {
            break;
        }
    }

    return puzzle;
}

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

fn printPuzzle(puzzle: *[]u8) !void {
    var stdout = std.io.getStdOut().writer();
    for (range(9)) |_, i| {
        for (range(9)) |_, j| {
            try stdout.print("{d} ", .{puzzle.*[i * 9 + j]});
        }
        try stdout.print("\n", .{});
    }
}
