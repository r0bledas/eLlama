using System.Runtime.InteropServices;

namespace eLlama;

public enum MemoryVerdict
{
    Ok,
    Near,
    Over
}

public sealed class MemoryEstimate
{
    public long WeightsBytes { get; init; }
    public long KvCacheBytes { get; init; }
    public long ComputeBufferBytes { get; init; }
    public long OverheadBytes { get; init; }
    public long LimitBytes { get; init; }

    public long TotalBytes => WeightsBytes + KvCacheBytes + ComputeBufferBytes + OverheadBytes;

    public double Fraction => LimitBytes > 0 ? (double)TotalBytes / LimitBytes : 0;
}

/// <summary>
/// Rough, header-free memory estimator. Approximates the KV cache of a
/// "generic Llama-like" decoder from the model file size and quantization only
/// (no GGUF metadata parsing). Treat the result as an order-of-magnitude
/// guardrail, not an exact figure. All magic numbers live here and are easy to tune.
/// </summary>
public static class MemoryEstimator
{
    // Tunable heuristic constants
    private const double ParamsDivisor = 196_608;   // params ~ 196608 * nLayer^3
    private const double EmbdPerLayer = 128;        // nEmbd ~ 128 * nLayer
    private const double HeadDim = 128;
    private const double KvHeadRatio = 0.25;        // GQA assumption: nHeadKV = nHead / 4
    private const double ComputeFactor = 8;         // bytes per (uBatch * nEmbd)
    private const long ComputeBase = 256L * 1024 * 1024;
    private const long OverheadBytes = 512L * 1024 * 1024;

    public static long TotalPhysicalMemoryBytes
    {
        get
        {
            try
            {
                var status = new MEMORYSTATUSEX();
                if (GlobalMemoryStatusEx(status))
                {
                    return (long)status.ullTotalPhys;
                }
            }
            catch
            {
                // Fall through to the managed fallback.
            }

            try
            {
                return GC.GetGCMemoryInfo().TotalAvailableMemoryBytes;
            }
            catch
            {
                return 0;
            }
        }
    }

    public static MemoryEstimate Estimate(
        long modelSizeBytes,
        string quant,
        int contextSize,
        int uBatchSize,
        string cacheTypeK,
        string cacheTypeV,
        long? limitBytes = null)
    {
        long limit = limitBytes ?? TotalPhysicalMemoryBytes;

        long weights = Math.Max(0, modelSizeBytes);
        double bpw = BitsPerWeight(quant);
        double parameters = bpw > 0 ? weights * 8.0 / bpw : 0;

        double nLayer = Math.Min(200, Math.Max(1, Math.Round(Math.Pow(parameters / ParamsDivisor, 1.0 / 3.0))));
        double nEmbd = EmbdPerLayer * nLayer;
        double nHead = Math.Max(1, nEmbd / HeadDim);
        double nHeadKv = Math.Max(1, Math.Round(nHead * KvHeadRatio));

        double bytesPerElemK = BytesPerElement(cacheTypeK);
        double bytesPerElemV = BytesPerElement(cacheTypeV);
        double kvPerToken = nLayer * nHeadKv * HeadDim * (bytesPerElemK + bytesPerElemV);
        long kvCache = (long)Math.Max(0, contextSize * kvPerToken);

        long computeBuffer = (long)Math.Max(0, Math.Max(uBatchSize, 0) * nEmbd * ComputeFactor + ComputeBase);

        return new MemoryEstimate
        {
            WeightsBytes = weights,
            KvCacheBytes = kvCache,
            ComputeBufferBytes = computeBuffer,
            OverheadBytes = OverheadBytes,
            LimitBytes = limit
        };
    }

    public static MemoryVerdict Verdict(MemoryEstimate estimate, int thresholdPercent)
    {
        if (estimate.LimitBytes <= 0) return MemoryVerdict.Ok;
        double fraction = estimate.Fraction;
        if (fraction >= 1.0) return MemoryVerdict.Over;
        if (fraction >= thresholdPercent / 100.0) return MemoryVerdict.Near;
        return MemoryVerdict.Ok;
    }

    public static double BitsPerWeight(string? quant)
    {
        string q = (quant ?? "").ToUpperInvariant();
        if (q.Contains("IQ1")) return 1.8;
        if (q.Contains("IQ2")) return 2.5;
        if (q.Contains("Q2")) return 2.6;
        if (q.Contains("IQ3")) return 3.2;
        if (q.Contains("Q3")) return 3.4;
        if (q.Contains("IQ4")) return 4.2;
        if (q.Contains("Q4")) return 4.8;
        if (q.Contains("Q5")) return 5.6;
        if (q.Contains("Q6")) return 6.6;
        if (q.Contains("Q8")) return 8.5;
        if (q.Contains("F32")) return 32;
        if (q.Contains("BF16") || q.Contains("F16")) return 16;
        return 4.8;
    }

    public static double BytesPerElement(string? cacheType)
    {
        switch ((cacheType ?? "").ToLowerInvariant())
        {
            case "f32": return 4;
            case "f16":
            case "bf16": return 2;
            case "q8_0": return 34.0 / 32.0;  // ~ 1.0625
            case "q5_0": return 22.0 / 32.0;  // ~ 0.6875
            case "q5_1": return 24.0 / 32.0;  // ~ 0.75
            case "q4_0": return 18.0 / 32.0;  // ~ 0.5625
            case "q4_1": return 20.0 / 32.0;  // ~ 0.625
            default: return 2;
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    private class MEMORYSTATUSEX
    {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;

        public MEMORYSTATUSEX()
        {
            dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
        }
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GlobalMemoryStatusEx([In, Out] MEMORYSTATUSEX lpBuffer);
}
