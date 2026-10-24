/// Standard CRC-32 (IEEE), the same checksum Ruby's `Zlib.crc32` gives Campfire for avatar colours.
enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB8_8320 : c >> 1 }
        return c
    }

    static func checksum(_ string: String) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in string.utf8 {
            c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
        }
        return ~c
    }
}
