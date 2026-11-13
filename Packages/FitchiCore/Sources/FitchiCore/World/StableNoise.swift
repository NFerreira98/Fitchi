/// A stable pseudo-random number in 0..<1 for a pair of integers (SplitMix64): the same inputs
/// always give the same answer, on every device. Drives everything that is "random but a pure
/// function of time": the pet's wandering, the day's weather.
public enum StableNoise {
    public static func value(_ seed: Int, _ index: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(bitPattern: Int64(index))
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value >> 11) / Double(UInt64(1) << 53)
    }

    /// Eases 0…1 in and out (smoothstep), clamping outside.
    public static func smooth(_ value: Double) -> Double {
        let clamped = min(1, max(0, value))
        return clamped * clamped * (3 - 2 * clamped)
    }
}
