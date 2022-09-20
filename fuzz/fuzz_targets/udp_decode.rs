#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    _ = rosc::decoder::decode_tcp(data);
    _ = rosc::decoder::decode_tcp_vec(data);
    _ = rosc::decoder::decode_udp(data);
});
