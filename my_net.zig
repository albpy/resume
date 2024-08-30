const std = @import("std");
const posix = std.posix;
//pub const sockaddr = system.sockaddr;
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const assert = std.debug.assert;
const posix_constants = @import("posix_constants.zig");
const mem = std.mem;
const my_mem = @import("my_mem.zig");
const my_err = @import("my_err.zig"); // errors from zig/lib/std/posix.zig
const protocols = @import("protocols.zig"); // instead of constant structs from zig/lib/std/os/linux.zig
const net_err = @import("my_net_err.zig");
const my_posix = @import("my_posix.zig");

const SOCK = protocols.SOCK;
const AF = protocols.AF;

pub const IPParseError = net_err.IPParseError;
pub const IPv4ParseError = IPParseError || error{NonCanonical};
pub const ListenError = net_err.ListenError;

pub const in_port_t = u16;
pub const sa_family_t = u16;
pub const socklen_t = u32;
const os = @import("std").os;
pub const sockaddr = os.linux.sockaddr;

// pub const sockaddr = extern struct {
//     family: sa_family_t,
//     data: [14]u8,

//     pub const SS_MAXSIZE = 128;
//     pub const storage = extern struct {
//         family: sa_family_t align(8),
//         padding: [SS_MAXSIZE - @sizeOf(sa_family_t)]u8 = undefined,

//         comptime {
//             assert(@sizeOf(storage) == SS_MAXSIZE);
//             assert(@alignOf(storage) == 8);
//         }
//     };

//     /// IPv4 socket address
//     pub const in = extern struct {
//         family: sa_family_t = AF.INET,
//         port: in_port_t,
//         addr: u32,
//         zero: [8]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
//     };

//     /// IPv6 socket address
//     pub const in6 = extern struct {
//         family: sa_family_t = AF.INET6,
//         port: in_port_t,
//         flowinfo: u32,
//         addr: [16]u8,
//         scope_id: u32,
//     };

//     /// UNIX domain socket address
//     pub const un = extern struct {
//         family: sa_family_t = AF.UNIX,
//         path: [108]u8,
// path - the file system path used by the socket. This path is crucial for UNIX domain sockets, as they are identified by file system paths rather than network addresses.
//     };

//     /// Packet socket address
//     pub const ll = extern struct {
//         family: sa_family_t = AF.PACKET,
//         protocol: u16,
//         ifindex: i32,
//         hatype: u16,
//         pkttype: u8,
//         halen: u8,
//         addr: [8]u8,
//     };

//     /// Netlink socket address
//     pub const nl = extern struct {
//         family: sa_family_t = AF.NETLINK,
//         __pad1: c_ushort = 0,

//         /// port ID
//         pid: u32,

//         /// multicast groups mask
//         groups: u32,
//     };

//     pub const xdp = extern struct {
//         family: u16 = AF.XDP,
//         flags: u16,
//         ifindex: u32,
//         queue_id: u32,
//         shared_umem_fd: u32,
//     };

//     /// Address structure for vSockets
//     pub const vm = extern struct {
//         family: sa_family_t = AF.VSOCK,
//         reserved1: u16 = 0,
//         port: u32,
//         cid: u32,
//         flags: u8,

//         /// The total size of this structure should be exactly the same as that of struct sockaddr.
//         zero: [3]u8 = [_]u8{0} ** 3,
//         comptime {
//             std.debug.assert(@sizeOf(vm) == @sizeOf(sockaddr));
//         }
//     };
// };

pub const Ip4Address = extern struct {
    sa: sockaddr.in,
    pub fn parse(buf: []const u8, port: u16) IPv4ParseError!Ip4Address {
        var result: Ip4Address = .{
            .sa = .{
                .port = my_mem.nativeToBig(u16, port),
                // we are telling the compiler we dont give a fuck about the state of that memory.
                // In release mode undefined will not write anything to the memory and will leave it in it's initial state. memory that an allocator recycles to be in a dirty state.
                // In debug mode  undefined will write to memory 0xAA(ie, 101010... pattern). this is to spot programming errors easily when using a debugger.
                .addr = undefined,
            },
        };
        std.debug.print("IPv4 address parsing started...\n", .{});
        // Given a pointer to a single item, returns a slice of the underlying bytes,
        // preserving pointer attributes. asBytes save ptr attributes before manipulating it.
        const out_ptr = my_mem.asBytes(&result.sa.addr);
        //*****************
        std.debug.print("out_ptr bytes before parse: ", .{});
        for (out_ptr) |byte| {
            //  formatted printing statement used for
            // displaying hexadecimal values of bytes to the console or standard output.
            // specifies that the argument (byte in this case) should be
            // formatted as a lowercase hexadecimal number (x),
            // padded with leading zeros (02)
            // to ensure at least two characters wide.
            std.debug.print("0x{x} ", .{byte});
        }
        std.debug.print("\n", .{});
        //*****************

        var x: u8 = 0;
        var index: u8 = 0;
        var saw_any_digits = false;
        var has_zero_prefix = false;
        for (buf) |c| {
            if (c == '.') {
                if (!saw_any_digits) {
                    return error.InvalidCharacter;
                }
                if (index == 3) {
                    return error.InvalidEnd;
                }
                out_ptr[index] = x;
                index += 1;
                x = 0;
                saw_any_digits = false;
                has_zero_prefix = false;
            } else if (c >= '0' and c <= '9') {
                if (c == '0' and !saw_any_digits) {
                    has_zero_prefix = true;
                } else if (has_zero_prefix) {
                    return error.NonCanonical;
                }
                saw_any_digits = true;
                x = try std.math.mul(u8, x, 10);
                x = try std.math.add(u8, x, c - '0');
            } else {
                return error.InvalidCharacter;
            }
        }
        if (index == 3 and saw_any_digits) {
            out_ptr[index] = x;
            
            std.debug.print("out_ptr bytes after parse: ", .{});
            for (out_ptr) |byte| {
                std.debug.print("0x{x} ", .{byte});
            }

            return result;
        }

        return error.Incomplete;
    }
    pub fn getOsSockLen(self: Ip4Address) posix.socklen_t {
        _ = self;
        return @sizeOf(posix.sockaddr.in);
    }
};

pub const Ip6Address = extern struct { sa: posix.sockaddr.in6 };

pub const has_unix_sockets = switch (native_os) {
    .windows => builtin.os.version_range.windows.isAtLeast(.win10_rs4) orelse false,
    else => true,
};

// store one value of many possible typed fields; only one field may be active at one time.
pub const Address = extern union {
    in: Ip4Address,
    any: sockaddr,

    pub fn resolveIp(name: []const u8, port: u16) !Address {
        std.log.info("ipv4 name {s}, port {d}", .{ name, port });
        if (parseIp4(name, port)) |ip4| return ip4 else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            error.NonCanonical,
            => {},
            else => return err,
        }

        return error.InvalidIPAddressFormat;
    }

    pub fn parseIp4(buf: []const u8, port: u16) IPv4ParseError!Address {
        return .{ .in = try Ip4Address.parse(buf, port) };
    }
    // The getOsSockLen function provides the correct length of the socket address structure
    // (sockaddr) depending on the address family (AF_INET, AF_INET6, AF_UNIX).
    // This length is used when interacting with low-level socket functions in the
    // POSIX API, such as bind, connect, accept, getsockname, and getpeername.
    pub fn getOsSockLen(self: Address) my_posix.socklen_t {
        switch (self.any.family) {
            protocols.AF.INET => return self.in.getOsSockLen(), // switch statement returns the first succesfull case
            //posix_constants.AF.INET6 => return self.in6.getOsSockLen(),
            protocols.AF.UNIX => {
                if (!has_unix_sockets) { // false
                    unreachable;
                }

                // Using the full length of the structure here is more portable than returning
                // the number of bytes actually used by the currently stored path.
                // This also is correct regardless if we are passing a socket address to the kernel
                // (e.g. in bind, connect, sendto) since we ensure the path is 0 terminated in
                // initUnix() or if we are receiving a socket address from the kernel and must
                // provide the full buffer size (e.g. getsockname, getpeername, recvfrom, accept).
                //
                // To access the path, std.mem.sliceTo(&address.un.path, 0) should be used.
                return @as(my_posix.socklen_t, @intCast(@sizeOf(sockaddr.un)));
            },

            else => unreachable,
        }
    }

    pub const ListenOptions = struct {
        /// How many connections the kernel will accept on the application's behalf.
        /// If more than this many connections pool in the kernel, clients will start
        /// seeing "Connection refused".
        kernel_backlog: u31 = 128,
        /// Sets SO_REUSEADDR and SO_REUSEPORT on POSIX.
        /// Sets SO_REUSEADDR on Windows, which is roughly equivalent.
        reuse_address: bool = false,
        /// Deprecated. Does the same thing as reuse_address.
        reuse_port: bool = false,
        force_nonblocking: bool = false,
    };

    /// The returned `Server` has an open `stream`.
    /// In network programming, a "stream" typically refers to a continuous flow of data between two points.
    /// For TCP/IP communication, this stream is represented by a socket that can read from and write to the network.
    /// Server struct in your code likely contains a field representing this stream
    pub fn listen(address: Address, options: ListenOptions) ListenError!Server {
        // SOCK.NONBLOCK = 0o4000
        // The traditional UNIX system calls are blocking
        //  If we make a call to, say, accept, and the call blocks, then we lose our ability to respond to other events.

        const nonblock: u32 = if (options.force_nonblocking) SOCK.NONBLOCK else 0; // 0 for us
           // SOCK_STREAM -  Provides sequenced, reliable, two-way, connection-based byte streams.  An out-of-band data transmission mechanism may be supported.
            // /*Standard socket types */
            // #define  SOCK_STREAM             1 /*virtual circuit*/
            // #define  SOCK_DGRAM              2 /*datagram*/
            // #define  SOCK_RAW                3 /*raw socket*/
            // #define  SOCK_RDM                4 /*reliably-delivered message*/
            // #define  SOCK_CONN_DGRAM         5 /*connection datagram*/

        // SOCK_CLOEXEC - Set the close-on-exec (FD_CLOEXEC) flag on the new file descriptor.
        // This flag ensures that the file descriptor is closed automatically when an exec family function (such as execve, execl, execp) is called.
        // This feature is particularly important for avoiding file descriptor leaks in multithreaded programs.
        // exec Functions:
        // The exec family of functions (execve, execl, execp, etc.) replaces the current process image with a new process image. This involves loading a new program into the current process's memory space and starting execution of that program.
        // if the close-on-exec flag is set on some file descriptors, those will be closed on exec, so that the subprocess cannot read/write the open descriptors and cannot keep the file open even if the Tcl interpreter terminates.




        // SOCK_NONBLOCK - Set the O_NONBLOCK file status flag on the open file description (see open(2)) referred to by the new file
        //      descriptor.  Using this flag saves extra calls to fcntl(2) to achieve the same result.
        // The flag can have significant effects on special file types such as FIFOs (named pipes), sockets, and certain character devices
        // eg : The server opens a listening socket with the O_NONBLOCK flag.

        // accept(): Accepts a new client connection. This call will not block if no clients are currently trying to connect.
        const sock_flags = SOCK.STREAM | SOCK.CLOEXEC | nonblock; // FOR US 1 | 0o2000000 | 0
        // 000000000000000000000001
        //|100000000000000000000000
        //|000000000000000000000000
        //------------------------
        // 100000000000000000000001

        const proto: u32 = if (address.any.family == AF.UNIX) 0 else protocols.IPPROTO.TCP; // if AF.UNIX 0 else 6
        // for us AF.INET thus 6
        // The server opens a listening socket with the O_NONBLOCK flag and returning an i32 value (file descriptor)
        // for further operations(handling the server). sockfd file descriptor opens
        const sockfd = try my_posix.socket(address.any.family, sock_flags, proto);
        std.log.info("sockfd value: {any}", .{sockfd}); // sockfd is 3 indicates that this is the third file descriptor allocated by the process.
        
        var s: Server = .{
            .listen_address = undefined,
            .stream = .{ .handle = sockfd },
        };
        
        errdefer s.stream.close(); // if function returns error s.stream.close() executed

        if (options.reuse_address or options.reuse_port) { // reuse address is true
            // instead odf posix.setsockopt handling the error
            // on success 0 is returned, on error -1 is returned
            try my_posix.setsockopt(
                sockfd,
                protocols.SOL.SOCKET, // 1 SOL - Socket Level -level: The protocol level at which the option resides(Here socket level)
                protocols.SO.REUSEADDR, // 2 SO - Socket Options - optname: The option to set(SO_REUSEADDR for the option to reuse addresses)
                &mem.toBytes(@as(c_int, 1)), // optval: A pointer to the value you want to set for the option. converts the integer 1 to a byte buffer and provides a pointer to it. This tells the socket to enable the SO_REUSEADDR option.
                // 1 enables reuse addr, 0 disables reuseaddr
            );
            std.log.info("getting mem buffer of reuse_addr: {*}", .{&mem.toBytes(@as(c_int, 1))});
            std.log.info("getting contents of mem buffer of reuse_addr: {any}", .{mem.toBytes(@as(c_int, 1))});
            if (@hasDecl(protocols.SO, "REUSEPORT")) { // "REUSEPORT" is declared in protocols.SO
                //@hasDecl - Zig compile-time function that checks if a particular declaration
                // (like a constant, function, or type) is present in the specified namespace or module.
                // @hasDecl(namespace, "name")

                // instead of posix.setsockopt
                try my_posix.setsockopt(
                    sockfd,
                    protocols.SOL.SOCKET, // 1
                    protocols.SO.REUSEPORT, //15
                    &mem.toBytes(@as(c_int, 1)), // Given any value, returns a copy of its bytes in an array.
                    // the setsockopt function expects a pointer to a block of memory containing the option value, not a higher-level data structure like a slice.
                );
            }
        }
        // The len parameter in the recv() function in Linux socket programming specifies the length 
        // in bytes of the buffer that receives data. 
        // getOsSockLen AF_INET it's 16 linux
        var socklen = address.getOsSockLen(); //len of address
        std.log.info("getsocklength gave length is : {any}", .{socklen});

        // Associates the socket with an IP address and port.
        try my_posix.bind(sockfd, &address.any, socklen);
        // Prepares the socket to accept incoming connections.
        try my_posix.listen(sockfd, options.kernel_backlog);
        // The getsockname function is a system call that retrieves the local address bound to a socket. This is useful for obtaining information about the socket's local endpoint, such as its IP address and port number.
        // The getsockname() call stores the current name for the socket specified by the s parameter into the structure pointed to by the name parameter. 

        try my_posix.getsockname(sockfd, &s.listen_address.any, &socklen);
        return s;
    }
};

fn convertSockaddr(my_sockaddr: sockaddr) ?std.os.linux.sockaddr {
    return ?std.os.linux.sockaddr{
        .family = my_sockaddr.family,
        .data = my_sockaddr.data,
    };
}
const io = std.io;
const windows = std.os.windows;
pub const Stream = struct {
    /// Underlying platform-defined type which may or may not be
    /// interchangeable with a file system file descriptor.
    handle: my_posix.socket_t,

    pub fn close(s: Stream) void {
        switch (native_os) {
            .windows => windows.closesocket(s.handle) catch unreachable,
            else => posix.close(s.handle),
        }
    }

    pub const ReadError = posix.ReadError;
    pub const WriteError = posix.WriteError;

    // zig/lib/std/io.zig
    // zig/lib/std/io.zig
    // pub inline fn print(self: Self, comptime format: []const u8, args: anytype) Error!void {
            // return @errorCast(self.any().print(format, args));
        // }
    pub const Reader = io.Reader(Stream, ReadError, read);
    pub const Writer = io.Writer(Stream, WriteError, write);

    pub fn reader(self: Stream) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: Stream) Writer {
        return .{ .context = self };
    }

    pub fn read(self: Stream, buffer: []u8) ReadError!usize {
        if (native_os == .windows) {
            return windows.ReadFile(self.handle, buffer, null);
        }

        return posix.read(self.handle, buffer);
    }

    pub fn readv(s: Stream, iovecs: []const posix.iovec) ReadError!usize {
        if (native_os == .windows) {
            // TODO improve this to use ReadFileScatter
            if (iovecs.len == 0) return @as(usize, 0);
            const first = iovecs[0];
            return windows.ReadFile(s.handle, first.base[0..first.len], null);
        }

        return posix.readv(s.handle, iovecs);
    }

    /// Returns the number of bytes read. If the number read is smaller than
    /// `buffer.len`, it means the stream reached the end. Reaching the end of
    /// a stream is not an error condition.
    pub fn readAll(s: Stream, buffer: []u8) ReadError!usize {
        return readAtLeast(s, buffer, buffer.len);
    }

    /// Returns the number of bytes read, calling the underlying read function
    /// the minimal number of times until the buffer has at least `len` bytes
    /// filled. If the number read is less than `len` it means the stream
    /// reached the end. Reaching the end of the stream is not an error
    /// condition.
    pub fn readAtLeast(s: Stream, buffer: []u8, len: usize) ReadError!usize {
        assert(len <= buffer.len);
        var index: usize = 0;
        while (index < len) {
            const amt = try s.read(buffer[index..]);
            if (amt == 0) break;
            index += amt;
        }
        return index;
    }

    /// TODO in evented I/O mode, this implementation incorrectly uses the event loop's
    /// file system thread instead of non-blocking. It needs to be reworked to properly
    /// use non-blocking I/O.
    pub fn write(self: Stream, buffer: []const u8) WriteError!usize {
        if (native_os == .windows) {
            return windows.WriteFile(self.handle, buffer, null);
        }

        return posix.write(self.handle, buffer);
    }

    pub fn writeAll(self: Stream, bytes: []const u8) WriteError!void {
        var index: usize = 0;
        while (index < bytes.len) {
            index += try self.write(bytes[index..]);
        }
    }

    /// See https://github.com/ziglang/zig/issues/7699
    /// See equivalent function: `std.fs.File.writev`.
    pub fn writev(self: Stream, iovecs: []const posix.iovec_const) WriteError!usize {
        return posix.writev(self.handle, iovecs);
    }

    /// The `iovecs` parameter is mutable because this function needs to mutate the fields in
    /// order to handle partial writes from the underlying OS layer.
    /// See https://github.com/ziglang/zig/issues/7699
    /// See equivalent function: `std.fs.File.writevAll`.
    pub fn writevAll(self: Stream, iovecs: []posix.iovec_const) WriteError!void {
        if (iovecs.len == 0) return;

        var i: usize = 0;
        while (true) {
            var amt = try self.writev(iovecs[i..]);
            while (amt >= iovecs[i].len) {
                amt -= iovecs[i].len;
                i += 1;
                if (i >= iovecs.len) return;
            }
            iovecs[i].base += amt;
            iovecs[i].len -= amt;
        }
    }
};

pub const Server = struct {
    listen_address: Address,
    stream: Stream, //std.net.Stream,

    pub const Connection = struct {
        stream: Stream,
        address: Address,
    };

    pub fn deinit(s: *Server) void {
        s.stream.close();
        s.* = undefined;
    }

    pub const AcceptError = posix.AcceptError;

    /// Blocks until a client connects to the server. The returned `Connection` has
    /// an open stream.
    pub fn accept(s: *Server) AcceptError!Connection {
        var accepted_addr: Address = undefined; 
        var addr_len: posix.socklen_t = @sizeOf(Address);
        const fd = try posix.accept(s.stream.handle, &accepted_addr.any, &addr_len, posix.SOCK.CLOEXEC);
        return .{
            .stream = .{ .handle = fd },
            .address = accepted_addr,
        };
    }
};


// Sock stream - Provides sequenced, two-way byte streams with a transmission mechanism for stream data. This socket type transmits data on a reliable basis, in order, and with out-of-band capabilities.
// In the UNIX domain, the SOCK_STREAM socket type works like a pipe. In the Internet domain, the SOCK_STREAM socket type is implemented on the Transmission Control Protocol/Internet Protocol (TCP/IP) protocol.
// A stream socket provides for the bidirectional, reliable, sequenced, and unduplicated flow of data without record boundaries. Aside from the bidirectionality of data flow, a pair of connected stream sockets provides an interface nearly identical to pipes.

// The SOCK_STREAM socket types are full-duplex byte streams. A stream socket must be connected before any data can be sent or received on it. When using a stream socket for data transfer, an application program needs to perform the following sequence:
// Create a connection to another socket with the connect subroutine.
// Use the read and write subroutines or the send and recv subroutines to transfer data.
// Use the close subroutine to finish the session.
// An application program can use the send and recv subroutines to manage out-of-band data.
// SOCK_STREAM communication protocols are designed to prevent the loss or duplication of data. If a piece of data for which the peer protocol has buffer space cannot be successfully transmitted within a reasonable period of time, the connection is broken. When this occurs, the socket subroutine indicates an error with a return value of -1 and the errno global variable is set to ETIMEDOUT. If a process sends on a broken stream, a SIGPIPE signal is raised. Processes that cannot handle the signal terminate. When out-of-band data arrives on a socket, a SIGURG signal is sent to the process group.
// The process group associated with a socket can be read or set by either the SIOCGPGRP or SIOCSPGRP ioctl operation. To receive a signal on any data, use both the SIOCSPGRP and FIOASYNC ioctl operations. These operations are defined in the sys/ioctl.h file.


// SOL SOCKET
// The level argument specifies the protocol level at which the option resides. To retrieve options at the socket level, specify the 
// level argument as SOL_SOCKET. To retrieve options at other levels, supply the appropriate protocol number for the protocol controlling 
// the option. For example, to indicate that an option will be interpreted by the TCP (Transport Control Protocol), set level to the protocol number of TCP, as defined in the 
// <netinet/in.h> header, or as determined by using getprotobyname() function.

// When retrieving a socket option, or setting it, you specify the option name as well as the level. When level = SOL_SOCKET, the item will be searched for in the socket itself.
// For example, suppose we want to set the socket option to reuse the address to 1 (on/true), we pass in the "level" SOL_SOCKET and the value we want it set to.
// int value = 1;    
// setsockopt(mysocket, SOL_SOCKET, SO_REUSEADDR, &value, sizeof(value));
// This will set the SO_REUSEADDR in my socket to 1.



// listen
// listen tells the TCP/IP stack to start accept incoming TCP connections on the port the socket is 
// binded to. The backlog parameter is not a "maximum number of connections allowed" parameter. Rather it's just a hint to the stack about how many TCP connections can be accepted on the socket's port before the applicaiton code has invoked accept on that socket. Be aware that accept doesn't negotiate a TCP handshake, it just takes one of the already accepted connections out of the backlog queue (or waits for one to arrive).

// accept linux
// The accept() call is used by a server to accept a connection request from a client. 
// When a connection is available, the socket created is ready for use to read data from the 
// process that requested the connection. The call accepts the first connection on its queue 
// of pending connections for the given socket socket. The accept() call creates a new socket 
// descriptor with the same properties as socket and returns it to the caller. If the queue 
// has no pending connection requests, accept() blocks the caller unless socket is in 
// nonblocking mode. If no connection requests are queued and socket is in nonblocking mode, 
// accept() returns -1 and sets the error code to EWOULDBLOCK. The new socket descriptor
// cannot be used to accept new connections. The original socket, socket, remains available 
// to accept more connection requests. 