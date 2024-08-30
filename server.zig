// zig build-exe server.zig -femit-bin=server_out/server -freference-trace=15 -target native-native-gnu -I. -lc -ldl -lrt

const std = @import("std");
const my_net = @import("my_net.zig");
const Address = my_net.Address;

const net = std.net;
const StreamServer = net.Server; // TCP
// const Address = net.Address;
pub const io_mode = .evented;
const mem = std.mem;
const expect = std.testing.expect;
const fs = std.fs;
const http = @import("HTTP_parser.zig");

pub fn server() anyerror!void {
    // custom code
    std.debug.print("Starting server\n", .{});
    // After calling resolveIp, the ip4 field within the Address union is active.
    const address = try Address.resolveIp("127.0.0.1", 8080);
    std.debug.print("IP Address: {}\n", .{address.in.sa.addr});
    std.debug.print("IP Family: {}\n", .{address.in.sa.family});
    std.debug.print("IP PORT: {}\n", .{address.in.sa.port});
    std.debug.print("IP Address Family: {any}\n", .{address.in.sa.zero});

    // const self_addr = try net.Address.resolveIp("127.0.0.1", 8080);
    // std.debug.print("IP Address: {}\n", .{self_addr.in.sa.addr});
    // std.debug.print("IP Address: {}\n", .{self_addr.in.sa.family});
    // std.debug.print("IP Address: {}\n", .{self_addr.in.sa.port});
    // std.debug.print("IP Address: {any}\n", .{self_addr.in.sa.zero});
    // linux listener
    var listener = try address.listen(.{ .reuse_address = true });
    std.debug.print("Listening on {}\n", .{address});

    while (listener.accept()) |conn| {
        std.debug.print("Accepted connection from: {}\n", .{conn.address});
        std.debug.print("conn is: {}\n", .{conn});
        std.debug.print("fd is: {}\n", .{conn.stream.handle});

        var recv_buf: [4096]u8 = undefined;
        var recv_total: usize = 0;
        // The loop attempts to read data from the connection stream into the buffer if connection stream has data.
        // read from the conn file descriptor. it returns the byte conts read which is stored to recv_len var.
        while (conn.stream.read(recv_buf[recv_total..])) |recv_len| {
            std.log.info("recv_len : {any}", .{recv_len}); // read file descriptor
            if (recv_len == 0) break; // end of the stream has been reached, the connection has been closed by other side.
            recv_total += recv_len;
            // Returns true if the haystack contains expected_count or more needles needle.len must be > 0 does not count overlapping needles
            // haystack - larger array and needle is the slice in the array, len is the occurance of the needle in haystack.
            if (mem.containsAtLeast(u8, recv_buf[0..recv_total], 1, "\r\n\r\n")) { // break all time when found an "\r\n\r\n"
                break;
            }
        } else |read_err| {
            return read_err;
        }
        std.log.info("recv_total : {any}", .{recv_total}); // size of obj in mem

        const recv_data = recv_buf[0..recv_total];
        // std.log.info("recv_data : {s}", .{recv_data});
        // if no data
        if (recv_data.len == 0) {
            // Browsers (or firefox?) attempt to optimize for speed
            // by opening a connection to the server once a user highlights
            // a link, but doesn't start sending the request until it's
            // clicked. The request eventually times out so we just
            // go agane.
            std.debug.print("Got connection but no header!\n", .{});
            continue;
        }
        // perse the http header to struct
        const header = try http.parseHeader(recv_data);
        // get the path in the request line
        const path = try http.parsePath(header.requestLine);

        std.log.info("[path to open] {s}", .{path});
        // determine the MIME type of a file based on its file extension. MIME types are used to specify the nature and format of a file,
        // and they are important in web servers and browsers to handle files correctly.
        const mime = http.mimeForPath(path);
        const buf = http.openLocalFile(path) catch |err| {
            if (err == error.FileNotFound) {
                _ = try conn.stream.writer().write(http.http404());
                continue;
            } else {
                return err;
            }
        };
        std.debug.print("SENDING----\n", .{});
        // std.log.info("file on buffer {s}", .{buf});
        std.log.info("buffer len {d}", .{buf.len});

        const httpHead =
            "HTTP/1.1 200 OK \r\n" ++
            "Connection: close\r\n" ++
            "Content-Type: {s}\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n";
        _ = try conn.stream.writer().print(httpHead, .{ mime, buf.len });
        _ = try conn.stream.writer().write(buf);
    } else |err| {
        std.debug.print("error in accept: {}\n", .{err});
    }
}

pub fn main() !void {
    try server();
}
