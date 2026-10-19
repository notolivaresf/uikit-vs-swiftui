import Foundation

/// Solid-colour PNG for a placeholder image, built by hand (stored deflate blocks) so no image framework
/// is needed. Used when a build wants real bytes (for example to test image decoding cost); drawing a
/// filled rectangle of `color` at the same pixel size is equivalent.
public enum Placeholder {
    public static func pngData(width: Int, height: Int, color: RGB) -> Data {
        var raw = Data()
        let row = [UInt8(0)] + (0..<width).flatMap { _ in [color.r, color.g, color.b] }
        for _ in 0..<height { raw.append(contentsOf: row) }

        var z = Data([0x78, 0x01])
        var offset = 0
        while offset < raw.count {
            let n = min(65_535, raw.count - offset)
            z.append(offset + n == raw.count ? 1 : 0)
            z.append(contentsOf: [UInt8(n & 0xFF), UInt8(n >> 8), UInt8(~n & 0xFF), UInt8((~n >> 8) & 0xFF)])
            z.append(raw[offset..<offset + n])
            offset += n
        }
        z.append(contentsOf: be32(adler32(raw)))

        var png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        var ihdr = Data()
        ihdr.append(contentsOf: be32(UInt32(width))); ihdr.append(contentsOf: be32(UInt32(height)))
        ihdr.append(contentsOf: [8, 2, 0, 0, 0])
        png.append(chunk("IHDR", ihdr)); png.append(chunk("IDAT", z)); png.append(chunk("IEND", Data()))
        return png
    }

    private static func chunk(_ type: String, _ body: Data) -> Data {
        var d = Data(); d.append(contentsOf: be32(UInt32(body.count)))
        var tb = Data(type.utf8); tb.append(body)
        d.append(tb); d.append(contentsOf: be32(crc32(tb)))
        return d
    }

    private static func be32(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8((v >> 16) & 255), UInt8((v >> 8) & 255), UInt8(v & 255)] }

    private static func adler32(_ d: Data) -> UInt32 {
        var a: UInt32 = 1, b: UInt32 = 0
        for x in d { a = (a + UInt32(x)) % 65521; b = (b + a) % 65521 }
        return (b << 16) | a
    }

    private static func crc32(_ d: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for x in d {
            c ^= UInt32(x)
            for _ in 0..<8 { c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB8_8320 : c >> 1 }
        }
        return ~c
    }
}
