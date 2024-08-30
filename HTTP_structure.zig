const std = @import("std");
pub const HeaderNames = enum {
    Host,
    @"User-Agent",
};

// requestLine : contains the request type, requested file name, and HTTP version
// host : the Requsting Domain name
// userAgent : Client-browser information
pub const HTTPHeader = struct {
    requestLine: []const u8,
    host: []const u8,
    userAgent: []const u8,

    pub fn print(self: HTTPHeader) void {
        std.debug.print("http requestline : {s} and - host : {s}\n", .{
            self.requestLine,
            self.host,
        });
    }
};

pub const mimeTypes = .{
    .{ ".html", "text/html" },
    .{ ".css", "text/css" },
    .{ ".png", "image/png" },
    .{ ".jpg", "image/jpeg" },
    .{ ".gif", "image/gif" },
};