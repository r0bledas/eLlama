import Foundation

public enum MemoryVerdict {
    case ok
    case near
    case over
}

public struct MemoryEstimate {
    public let weightsBytes: Int64
    public let kvCacheBytes: Int64
    public let computeBufferBytes: Int64
    public let overheadBytes: Int64
    public let limitBytes: Int64

    public var totalBytes: Int64 {
        weightsBytes + kvCacheBytes + computeBufferBytes + overheadBytes
    }

    public var fraction: Double {
        limitBytes > 0 ? Double(totalBytes) / Double(limitBytes) : 0
    }
}

/// Rough, header-free memory estimator. It approximates the KV cache of a
/// "generic Llama-like" decoder from the model file size and quantization only
/// (no GGUF metadata parsing). Treat the result as an order-of-magnitude guardrail,
/// not an exact figure. All magic numbers live here and are easy to tune.
public final class MemoryEstimator {
    public static let shared = MemoryEstimator()

    public init() {}

    // MARK: - Tunable heuristic constants
    private static let paramsDivisor: Double = 196_608      // params ≈ 196608 · nLayer³
    private static let embdPerLayer: Double = 128           // nEmbd ≈ 128 · nLayer
    private static let headDim: Double = 128
    private static let kvHeadRatio: Double = 0.25           // GQA assumption: nHeadKV = nHead / 4
    private static let computeFactor: Double = 8            // bytes per (uBatch × nEmbd)
    private static let computeBase: Double = 256 * 1024 * 1024
    private static let overheadBytes: Double = 512 * 1024 * 1024

    public static var physicalMemoryBytes: Int64 {
        Int64(ProcessInfo.processInfo.physicalMemory)
    }

    public func estimate(
        modelSizeBytes: Int64,
        quant: String,
        contextSize: Int,
        uBatchSize: Int,
        cacheTypeK: String,
        cacheTypeV: String,
        limitBytes: Int64? = nil
    ) -> MemoryEstimate {
        let limit = limitBytes ?? Self.physicalMemoryBytes

        let weights = max(0, modelSizeBytes)
        let bpw = Self.bitsPerWeight(for: quant)
        let params = bpw > 0 ? Double(weights) * 8.0 / bpw : 0

        let nLayer = min(200, max(1, pow(params / Self.paramsDivisor, 1.0 / 3.0).rounded()))
        let nEmbd = Self.embdPerLayer * nLayer
        let nHead = max(1, nEmbd / Self.headDim)
        let nHeadKV = max(1, (nHead * Self.kvHeadRatio).rounded())

        let bytesPerElemK = Self.bytesPerElement(for: cacheTypeK)
        let bytesPerElemV = Self.bytesPerElement(for: cacheTypeV)
        let kvPerToken = nLayer * nHeadKV * Self.headDim * (bytesPerElemK + bytesPerElemV)
        let kvCache = Int64(max(0, Double(contextSize) * kvPerToken))

        let computeBuf = Int64(max(0, Double(max(uBatchSize, 0)) * nEmbd * Self.computeFactor + Self.computeBase))
        let overhead = Int64(Self.overheadBytes)

        return MemoryEstimate(
            weightsBytes: weights,
            kvCacheBytes: kvCache,
            computeBufferBytes: computeBuf,
            overheadBytes: overhead,
            limitBytes: limit
        )
    }

    public func verdict(for estimate: MemoryEstimate, thresholdPercent: Int) -> MemoryVerdict {
        guard estimate.limitBytes > 0 else { return .ok }
        let fraction = estimate.fraction
        if fraction >= 1.0 { return .over }
        if fraction >= Double(thresholdPercent) / 100.0 { return .near }
        return .ok
    }

    // MARK: - Approximation tables
    public static func bitsPerWeight(for quant: String) -> Double {
        let q = quant.uppercased()
        if q.contains("IQ1") { return 1.8 }
        if q.contains("IQ2") { return 2.5 }
        if q.contains("Q2") { return 2.6 }
        if q.contains("IQ3") { return 3.2 }
        if q.contains("Q3") { return 3.4 }
        if q.contains("IQ4") { return 4.2 }
        if q.contains("Q4") { return 4.8 }
        if q.contains("Q5") { return 5.6 }
        if q.contains("Q6") { return 6.6 }
        if q.contains("Q8") { return 8.5 }
        if q.contains("F32") { return 32 }
        if q.contains("BF16") || q.contains("F16") { return 16 }
        return 4.8
    }

    public static func bytesPerElement(for cacheType: String) -> Double {
        switch cacheType.lowercased() {
        case "f32": return 4
        case "f16", "bf16": return 2
        case "q8_0": return 34.0 / 32.0   // ≈ 1.0625
        case "q5_0": return 22.0 / 32.0   // ≈ 0.6875
        case "q5_1": return 24.0 / 32.0   // ≈ 0.75
        case "q4_0": return 18.0 / 32.0   // ≈ 0.5625
        case "q4_1": return 20.0 / 32.0   // ≈ 0.625
        default: return 2
        }
    }
}
