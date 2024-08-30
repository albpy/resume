const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const http_sructs = @import("HTTP_structure.zig");
const http_err = @import("HTTP_error.zig");
// terminated array by specifyiing a value.
// The sentinel can be any value of the slice's element type.
// Commonly used for strings, but applicable to any type.
// sentinal terminated -> Use the syntax: [N:sentinel]T or [:sentinel]T


// parse the header of the http request
pub fn parseHeader(header: []const u8) !http_sructs.HTTPHeader {
    // header : received data
    // parse the information out of the received data
    std.debug.print("Parsing data...", .{});
    var headerStruct = http_sructs.HTTPHeader{
        .requestLine = undefined,
        .host = undefined,
        .userAgent = undefined,
    };  
    // Header fields are colon-separated key-value pairs in clear-text string format,
    // terminated by a carriage return (CR)(\r) and line feed (\n) (LF).
    // Returns an iterator that iterates over the slices of buffer that are not the sequence in delimiter.
    var headerIter = mem.tokenizeSequence(u8, header, "\r\n");
    std.log.info("headerIter after tokenizeScalar: {d}, {s}, {c}", .{ headerIter.index, headerIter.buffer, headerIter.delimiter });

    headerStruct.requestLine = headerIter.next() orelse return http_err.ServeFileError.HeaderMalformed;
    while (headerIter.next()) |line| {
        std.log.info("line in headeriter.next() {s}", .{line});
        // Takes an array, a pointer to an array, a sentinel-terminated pointer, 
        // or a slice and iterates searching for the first occurrence of end, returning the scanned 
        // slice. If end is not found, the full length of the array/slice/sentinel terminated pointer is returned. If the pointer type is sentinel terminated and end matches that terminator, the resulting slice is also sentinel terminated. Pointer properties such as mutability and alignment are preserved. C pointers are assumed to be non-null.
        const nameSlice = mem.sliceTo(line, ':');
        std.log.info("nameslice is {s}", .{nameSlice});
        if (nameSlice.len == line.len) return http_err.ServeFileError.HeaderMalformed;
        //stringToEnum - Returns the variant of an enum type, T, which is named str, or null if no such variant exists.
        // orelse continue part means that if stringToEnum returns null
        const headerName = std.meta.stringToEnum(http_sructs.HeaderNames, nameSlice) orelse continue;
        std.log.info("converted to enum using stringToEnum: {any}", .{headerName});
        // Remove a set of values from the beginning of a slice.
        // type of elem in the array, array to trim, value_to_strip
        const headerValue = mem.trimLeft(u8, line[nameSlice.len + 1 ..], " ");
        switch (headerName) {
            // .Host => headerStruct.host -> The code is checking what the  headerName equals "Host".
            .Host => headerStruct.host = headerValue,
            //.@"User-Agent" => headerStruct.userAgent -> The code is checking what the  headerName equals ".@"User-Agent"".
            .@"User-Agent" => headerStruct.userAgent = headerValue,
        }
    }
    // Logging the parsed header
    std.debug.print("Parsed HTTP Header:\n", .{});
    // line asking the resourse to the server.
    std.debug.print("Request Line: {s}\n", .{headerStruct.requestLine});
    std.debug.print("Host: {s}\n", .{headerStruct.host});
    std.debug.print("User-Agent: {s}\n", .{headerStruct.userAgent});
    return headerStruct;
}

pub fn parsePath(requestLine: []const u8) ![]const u8 {
    // Returns an iterator that iterates over the slices of buffer that are not delimiter.
    //   Returns an iterator that iterates over the slices of `buffer` that are not
    // `delimiter`.
    //
    // `tokenizeScalar(u8, "   abc def     ghi  ", ' ')` will return slices
    // for "abc", "def", "ghi", null, in that order.
    //
    // If `buffer` is empty, the iterator will return null.
    // If `delimiter` does not exist in buffer,
    // the iterator will return `buffer`, null, in that order.///
    //                                      comptime type, buffer, delimiter
    var requestLineIter = mem.tokenizeScalar(u8, requestLine, ' ');
    std.log.info("requestLineIter after tokenizeScalar: {d}, {s}, {c}", .{ requestLineIter.index, requestLineIter.buffer, requestLineIter.delimiter });
    const method = requestLineIter.next().?;
    if (!mem.eql(u8, method, "GET")) return http_err.ServeFileError.MethodNotSupported;
    const path = requestLineIter.next().?;
    if (path.len <= 0) return error.NoPath;
    const proto = requestLineIter.next().?;
    if (!mem.eql(u8, proto, "HTTP/1.1")) return http_err.ServeFileError.ProtoNotSupported;
    if (mem.eql(u8, path, "/")) {
        return "/about.html";
    }
    std.log.info("parsed path : {s}", .{path});
    return path;
}
//determine the MIME type of a file based on its file extension. MIME types are used to specify the nature and format of a file,
// and they are important in web servers and browsers to handle files correctly.
pub fn mimeForPath(path: []const u8) []const u8 {
    const extension = std.fs.path.extension(path);
    inline for (http_sructs.mimeTypes) |kv| {
        if (mem.eql(u8, extension, kv[0])) {
            return kv[1];
        }
    }
    return "application/octet-stream";
}

pub fn openLocalFile(path: []const u8) ![]u8 {
    const localPath = path[1..];
    const file = fs.cwd().openFile(localPath, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("File not found: {s}\n", .{localPath});
            return error.FileNotFound;
        },
        else => return err,
    };
    defer file.close();
    std.debug.print("file: {}\n", .{file});
    const memory = std.heap.page_allocator;
    const maxSize = std.math.maxInt(usize);
    return try file.readToEndAlloc(memory, maxSize);
}

pub fn http404() []const u8 {
    return "HTTP/1.1 404 NOT FOUND \r\n" ++
        "Connection: close\r\n" ++
        "Content-Type: text/html; charset=utf8\r\n" ++
        "Content-Length: 9\r\n" ++
        "\r\n" ++
        "NOT FOUND";
}
