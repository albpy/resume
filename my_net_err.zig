
pub const my_err = @import("my_err.zig");

pub const IPParseError = error{
    Overflow,
    InvalidEnd,
    InvalidCharacter,
    Incomplete,
};

pub const ListenError = my_err.SocketError || my_err.BindError || my_err.ListenError ||
        my_err.SetSockOptError || my_err.GetSockNameError;