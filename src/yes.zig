// SPDX-License-Identifier: 0BSD

const std = @import("std");

pub fn main() !u8 {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    const message = if (args.len > 1) try std.mem.join(allocator, " ", args[1..]) else "y";
    const final_message = try allocator.alloc(u8, message.len + 1);

    // appending a newline to the end of final_message
    std.mem.copyForwards(u8, final_message, message);
    final_message[final_message.len - 1] = '\n';

    // here I create a buffer and fill it with the newline appended message
    const page_size = std.heap.pageSize();
    const buf_size = try std.math.ceilPowerOfTwo(usize, @max(final_message.len, page_size * 2)); // ensure buffer is large enough for message
    var buf = try std.heap.page_allocator.alignedAlloc(u8, page_size, buf_size);

    var pos: usize = 0;
    while (pos + final_message.len <= buf.len) : (pos += final_message.len) {
        std.mem.copyForwards(u8, buf[pos..], final_message);
    } else {
        @memset(buf[pos..], 0); // fill rest of buffer with zeroes to avoid garbage output
    }

    // freeing the memory here is really funny since it's almost neglible compared to the giant buffer
    arena.deinit();

    while (true) {
        stdout.writeAll(buf) catch |err| {
            if (err == error.BrokenPipe) return 0;
            try stderr.print("write error: {}", .{err});
            return 1;
        };
    }
}

// NOTE
//
// This whole program could be a simple loop that just outputs to stdout BUT
// I was curious why GNU's yes program was so fast - ~8GiB/s on my machine! It
// turns out they buffered their IO for page aligned writes, so I copied that
// technique here for the learning experience. A much simpler solution might
// look like:
//
//
// const std = @import("std");

// pub fn main() !void {
//     const stdout = std.io.getStdOut().writer();
//     const args = try std.process.argsAlloc(std.heap.page_allocator);
//     const message = if (args.len > 1) try std.mem.join(std.heap.page_allocator, " ", args[1..]) else "y";

//     std.process.argsFree(std.heap.page_allocator, args);

//     while (true) try stdout.print("{s}\n", .{message});
// }
//
//
// If you're curious the speed difference, here's some metrics from my system,
// measured with "<program> | pv -aSs 1T" (quits at 1TiB written):
//
// tool    | buf?       | avg
// ---------------------------------
// my yes  | unbuffered | ...
// my yes  | buffered   | 8.22GiB/s
// GNU yes | buffered   | 8.22GiB/s
//
// And yes, I really did wait for the unbuffered one to write 1TiB...
