const std = @import("std");

pub const builtin = @import("my_builtin.zig").builtin;

const native_os = builtin.os.tag;

const my_err = @import("my_err.zig");

const my_linux = @import("my_linux.zig"); //system

const my_net = @import("my_net.zig");

pub const socklen_t = my_linux.socklen_t;

pub const protocols = @import("protocols.zig");
pub const PF = protocols.PF;
pub const AF = protocols.AF;
pub const IPPORT_RESERVED = protocols.IPPORT_RESERVED;
pub const IPPROTO = protocols.IPPROTO;
pub const SOL = protocols.SOL;
pub const SO = protocols.SO;
pub const SOCK = protocols.SOCK;

pub const ACCMODE = enum(u2) {
    RDONLY = 0,
    WRONLY = 1,
    RDWR = 2,
};

//const linux = std.os.linux;
const windows = std.os.windows;
const wasi = std.os.wasi;

pub const fd_t = my_linux.fd_t;

pub const socket_t = if (native_os == .windows) windows.ws2_32.SOCKET else fd_t;

// from posix.zig
pub fn socket(domain: u32, socket_type: u32, protocol: u32) my_err.SocketError!socket_t {
    // domain - domain of the protocol;
    // socket_type : protocol flags
    // protocol - for us tcp
    if (native_os == .windows) {
        // NOTE: windows translates the SOCK.NONBLOCK/SOCK.CLOEXEC flags into
        // windows-analogous operations
        const filtered_sock_type = socket_type & ~@as(u32, SOCK.NONBLOCK | SOCK.CLOEXEC);
        const flags: u32 = if ((socket_type & SOCK.CLOEXEC) != 0)
            windows.ws2_32.WSA_FLAG_NO_HANDLE_INHERIT
        else
            0;
        const rc = try windows.WSASocketW(
            @bitCast(domain),
            @bitCast(filtered_sock_type),
            @bitCast(protocol),
            null,
            0,
            flags,
        );
        errdefer windows.closesocket(rc) catch unreachable;
        if ((socket_type & SOCK.NONBLOCK) != 0) {
            var mode: c_ulong = 1; // nonblocking
            if (windows.ws2_32.SOCKET_ERROR == windows.ws2_32.ioctlsocket(rc, windows.ws2_32.FIONBIO, &mode)) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    // have not identified any error codes that should be handled yet
                    else => unreachable,
                }
            }
        }
        return rc;
    }
    // have_sock_flags: A boolean indicating if the current platform supports certain socket flags 
    const have_sock_flags = !builtin.target.isDarwin() and native_os != .haiku; // givs true
    // performs a bitwise AND with socket_type, effectively clearing the NONBLOCK and CLOEXEC bits if they are set.
    const filtered_sock_type = if (!have_sock_flags) 
        socket_type & ~@as(u32, SOCK.NONBLOCK | SOCK.CLOEXEC)
    else // for us true thus this will be executed
        socket_type;

    std.debug.print("my_posix socket domain : {}, filtered_sock_type : {}, protocol : {}\n", .{domain, filtered_sock_type, protocol});
    // us it is 2, 524289, 6 respectively.
    const rc = std.os.linux.socket(domain, filtered_sock_type, protocol);
    std.debug.print("rc(return code) type: {}\n", .{@TypeOf(rc)});
    std.debug.print("rc(return code) value: {}\n", .{rc});

    switch (my_err.errno(rc)) {
        .SUCCESS => {
            const fd: my_linux.fd_t =  @intCast(rc);
            errdefer close(fd);
            if (!have_sock_flags) {
                try setSockFlags(fd, socket_type);
            }
            return fd;
        },
        .ACCES => return error.PermissionDenied,
        .AFNOSUPPORT => return error.AddressFamilyNotSupported,
        .INVAL => return error.ProtocolFamilyNotAvailable,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOBUFS => return error.SystemResources,
        .NOMEM => return error.SystemResources,
        .PROTONOSUPPORT => return error.ProtocolNotSupported,
        .PROTOTYPE => return error.SocketTypeNotSupported,
        else => |err| return my_err.unexpectedErrno(err),
    }
}


// setsockopt from posix.zig
/// Set a socket's options.
pub fn setsockopt(fd: socket_t, level: i32, optname: u32, opt: []const u8) my_err.SetSockOptError!void {
    if (native_os == .windows) {
        const rc = windows.ws2_32.setsockopt(fd, level, @intCast(optname), opt.ptr, @intCast(opt.len));
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAEFAULT => unreachable,
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEINVAL => return error.SocketNotBound,
                else => |err| return windows.unexpectedWSAError(err),
            }
        }
        return;
    } else {
        switch (my_err.errno(my_linux.setsockopt(fd, level, optname, opt.ptr, @intCast(opt.len)))) { // Call posix setsockopt(systemcall)  
            .SUCCESS => {},
            .BADF => unreachable, // always a race condition
            .NOTSOCK => unreachable, // always a race condition
            .INVAL => unreachable,
            .FAULT => unreachable,
            .DOM => return error.TimeoutTooBig,
            .ISCONN => return error.AlreadyConnected,
            .NOPROTOOPT => return error.InvalidProtocolOption,
            .NOMEM => return error.SystemResources,
            .NOBUFS => return error.SystemResources,
            .PERM => return error.PermissionDenied,
            .NODEV => return error.NoDevice,
            else => |err| return my_err.unexpectedErrno(err),
        }
    }
}

// from posix.zig
pub fn close(fd: my_linux.fd_t) void {
    if (native_os == .windows) {
        return windows.CloseHandle(fd);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        _ = std.os.wasi.fd_close(fd);
        return;
    }
    switch (my_err.errno(my_linux.close(fd))) {
        .BADF => unreachable, // Always a race condition.
        .INTR => return, // This is still a success. See https://github.com/ziglang/zig/issues/2425
        else => return,
    }
}


fn setSockFlags(sock: socket_t, flags: u32) !void {
    if ((flags & SOCK.CLOEXEC) != 0) {
        if (native_os == .windows) {
            // TODO: Find out if this is supported for sockets
        } else {
            var fd_flags =  my_linux.fcntl(sock, my_linux.F.GETFD, 0) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
            fd_flags |= my_linux.FD_CLOEXEC;
            _ = my_linux.fcntl(sock, my_linux.F.SETFD, fd_flags) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
        }
    }
    if ((flags & SOCK.NONBLOCK) != 0) {
        if (native_os == .windows) {
            var mode: c_ulong = 1;
            if (windows.ws2_32.ioctlsocket(sock, windows.ws2_32.FIONBIO, &mode) == windows.ws2_32.SOCKET_ERROR) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    .WSANOTINITIALISED => unreachable,
                    .WSAENETDOWN => return error.NetworkSubsystemFailed,
                    .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                    // TODO: handle more errors
                    else => |err| return windows.unexpectedWSAError(err),
                }
            }
        } else {
            var fl_flags = my_linux.fcntl(sock, my_linux.F.GETFL, 0) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
            fl_flags |= 1 << @bitOffsetOf(protocols.O, "NONBLOCK");
            _ = my_linux.fcntl(sock, my_linux.F.SETFL, fl_flags) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
        }
    }
}

/// addr is `*const T` where T is one of the sockaddr
pub fn bind(sock: socket_t, addr: *const my_net.sockaddr, len: socklen_t) my_err.BindError!void {
    if (native_os == .windows) {
        const rc = windows.bind(sock, addr, len);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable, // not initialized WSA
                .WSAEACCES => return error.AccessDenied,
                .WSAEADDRINUSE => return error.AddressInUse,
                .WSAEADDRNOTAVAIL => return error.AddressNotAvailable,
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEFAULT => unreachable, // invalid pointers
                .WSAEINVAL => return error.AlreadyBound,
                .WSAENOBUFS => return error.SystemResources,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                else => |err| return windows.unexpectedWSAError(err),
            }
            unreachable;
        }
        return;
    } else {
        const rc = my_linux.bind(sock, addr, len);
        switch (my_err.errno(rc)) {
            .SUCCESS => return,
            .ACCES, .PERM => return error.AccessDenied,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => unreachable, // always a race condition if this error is returned
            .INVAL => unreachable, // invalid parameters
            .NOTSOCK => unreachable, // invalid `sockfd`
            .AFNOSUPPORT => return error.AddressFamilyNotSupported,
            .ADDRNOTAVAIL => return error.AddressNotAvailable,
            .FAULT => unreachable, // invalid `addr` pointer
            .LOOP => return error.SymLinkLoop,
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.NotDir,
            .ROFS => return error.ReadOnlyFileSystem,
            else => |err| return my_err.unexpectedErrno(err),
        }
    }
    unreachable;
}

pub fn listen(sock: socket_t, backlog: u31) my_err.ListenError!void {
    if (native_os == .windows) {
        const rc = windows.listen(sock, backlog);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable, // not initialized WSA
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAEADDRINUSE => return error.AddressInUse,
                .WSAEISCONN => return error.AlreadyConnected,
                .WSAEINVAL => return error.SocketNotBound,
                .WSAEMFILE, .WSAENOBUFS => return error.SystemResources,
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEOPNOTSUPP => return error.OperationNotSupported,
                .WSAEINPROGRESS => unreachable,
                else => |err| return windows.unexpectedWSAError(err),
            }
        }
        return;
    } else {
        const rc = my_linux.listen(sock, backlog);
        switch (my_err.errno(rc)) {
            .SUCCESS => return,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => unreachable,
            .NOTSOCK => return error.FileDescriptorNotASocket,
            .OPNOTSUPP => return error.OperationNotSupported,
            else => |err| return my_err.unexpectedErrno(err),
        }
    }
}

pub fn getsockname(sock: socket_t, addr: *my_net.sockaddr, addrlen: *socklen_t) my_err.GetSockNameError!void {
    if (native_os == .windows) {
        const rc = windows.getsockname(sock, addr, addrlen);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAEFAULT => unreachable, // addr or addrlen have invalid pointers or addrlen points to an incorrect value
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEINVAL => return error.SocketNotBound,
                else => |err| return windows.unexpectedWSAError(err),
            }
        }
        return;
    } else {
        const rc = my_linux.getsockname(sock, addr, addrlen);
        switch (my_err.errno(rc)) {
            .SUCCESS => return,
            else => |err| return my_err.unexpectedErrno(err),

            .BADF => unreachable, // always a race condition
            .FAULT => unreachable,
            .INVAL => unreachable, // invalid parameters
            .NOTSOCK => return error.FileDescriptorNotASocket,
            .NOBUFS => return error.SystemResources,
        }
    }
}

// pub fn accept(
//     /// This argument is a socket that has been created with `socket`, bound to a local address
//     /// with `bind`, and is listening for connections after a `listen`.
//     sock: socket_t,
//     /// This argument is a pointer to a sockaddr structure.  This structure is filled in with  the
//     /// address  of  the  peer  socket, as known to the communications layer.  The exact format of the
//     /// address returned addr is determined by the socket's address  family  (see  `socket`  and  the
//     /// respective  protocol  man  pages).
//     addr: ?*sockaddr,
//     /// This argument is a value-result argument: the caller must initialize it to contain  the
//     /// size (in bytes) of the structure pointed to by addr; on return it will contain the actual size
//     /// of the peer address.
//     ///
//     /// The returned address is truncated if the buffer provided is too small; in this  case,  `addr_size`
//     /// will return a value greater than was supplied to the call.
//     addr_size: ?*socklen_t,
//     /// The following values can be bitwise ORed in flags to obtain different behavior:
//     /// * `SOCK.NONBLOCK` - Set the `NONBLOCK` file status flag on the open file description (see `open`)
//     ///   referred  to by the new file descriptor.  Using this flag saves extra calls to `fcntl` to achieve
//     ///   the same result.
//     /// * `SOCK.CLOEXEC`  - Set the close-on-exec (`FD_CLOEXEC`) flag on the new file descriptor.   See  the
//     ///   description  of the `CLOEXEC` flag in `open` for reasons why this may be useful.
//     flags: u32,
// ) AcceptError!socket_t {
//     const have_accept4 = !(builtin.target.isDarwin() or native_os == .windows or native_os == .haiku);
//     assert(0 == (flags & ~@as(u32, SOCK.NONBLOCK | SOCK.CLOEXEC))); // Unsupported flag(s)

//     const accepted_sock: socket_t = while (true) {
//         const rc = if (have_accept4)
//             system.accept4(sock, addr, addr_size, flags)
//         else if (native_os == .windows)
//             windows.accept(sock, addr, addr_size)
//         else
//             system.accept(sock, addr, addr_size);

//         if (native_os == .windows) {
//             if (rc == windows.ws2_32.INVALID_SOCKET) {
//                 switch (windows.ws2_32.WSAGetLastError()) {
//                     .WSANOTINITIALISED => unreachable, // not initialized WSA
//                     .WSAECONNRESET => return error.ConnectionResetByPeer,
//                     .WSAEFAULT => unreachable,
//                     .WSAEINVAL => return error.SocketNotListening,
//                     .WSAEMFILE => return error.ProcessFdQuotaExceeded,
//                     .WSAENETDOWN => return error.NetworkSubsystemFailed,
//                     .WSAENOBUFS => return error.FileDescriptorNotASocket,
//                     .WSAEOPNOTSUPP => return error.OperationNotSupported,
//                     .WSAEWOULDBLOCK => return error.WouldBlock,
//                     else => |err| return windows.unexpectedWSAError(err),
//                 }
//             } else {
//                 break rc;
//             }
//         } else {
//             switch (errno(rc)) {
//                 .SUCCESS => break @intCast(rc),
//                 .INTR => continue,
//                 .AGAIN => return error.WouldBlock,
//                 .BADF => unreachable, // always a race condition
//                 .CONNABORTED => return error.ConnectionAborted,
//                 .FAULT => unreachable,
//                 .INVAL => return error.SocketNotListening,
//                 .NOTSOCK => unreachable,
//                 .MFILE => return error.ProcessFdQuotaExceeded,
//                 .NFILE => return error.SystemFdQuotaExceeded,
//                 .NOBUFS => return error.SystemResources,
//                 .NOMEM => return error.SystemResources,
//                 .OPNOTSUPP => unreachable,
//                 .PROTO => return error.ProtocolFailure,
//                 .PERM => return error.BlockedByFirewall,
//                 else => |err| return unexpectedErrno(err),
//             }
//         }
//     };

//     errdefer switch (native_os) {
//         .windows => windows.closesocket(accepted_sock) catch unreachable,
//         else => close(accepted_sock),
//     };
//     if (!have_accept4) {
//         try setSockFlags(accepted_sock, flags);
//     }
//     return accepted_sock;
// }

