# eLlama

**eLlama** is a fast, native Windows desktop manager and launcher for local GGUF large language models, powered directly by [`llama.cpp`](https://github.com/ggml-org/llama.cpp).

Unlike traditional local runners that duplicate model weights into internal blob layers and eat gigabytes of disk space, eLlama executes `.gguf` files directly in place with **zero file copying**, **zero background daemons**, and **zero overhead**.

---

## Key Features

- **Zero-Copy In-Place Execution**: Streams `.gguf` models directly from your folder without duplicating disk space.
- **Fast Instant Search**: Real-time filtering across model names, publishers, quantization types, and filenames.
- **Vision Projector Auto-Filter**: Automatically recognizes and isolates vision projector files (`mmproj`) so your model list remains clean.
- **Interactive Terminal Chat**: Launch models into full interactive multi-turn conversations with a single double-click or by hitting Enter.
- **Numerical Sorting**: One-click sorting by file size (calculated numerically by bytes), model name, quant, or publisher.

---

## Advanced Inference Settings

eLlama includes full fine-grained control over inference, memory, and sampling:

### Hardware & Compute
- **CPU Threads (`-t`)**: Configurable thread allocation (1–64).
- **GPU Offload (`-ngl`)**: Offload model layers to GPU (Vulkan / CUDA / OpenCL) or set to `0` for pure CPU inference.
- **Context Size (`-c`)**: Built-in presets (`1024`, `2048`, `4096`, `8192`, `16384`, `32768`, `65536`) with **8K as default**, plus a dedicated **Custom Context** input for arbitrary token limits.
- **Batch & Micro-Batch Sizes (`-b` / `-ub`)**: Configurable prompt processing batch sizes.

### KV Cache & Memory Optimization
- **Quantized KV Cache (`-ctk` / `-ctv`)**: Select between `f16`, `q8_0`, and `q4_0` to drastically cut RAM usage during long context sessions.
- **Flash Attention (`-fa`)**: Toggle Flash Attention (`auto`, `on`, `off`) for faster inference and memory efficiency.
- **Memory Locking (`--mlock`)**: Lock weights into physical RAM to prevent OS disk paging.
- **Direct Memory Loading (`--no-mmap`)**: Disable memory mapping when needed.

### Sampling & Generation
- **Temperature (`--temp`)**: Precise control from `0.00` (deterministic/coding) to `2.00` (creative).
- **Top-P (`--top-p`)** & **Top-K (`--top-k`)**: Dual nucleus and cutoff sampling.
- **Min-P (`--min-p`)**: Minimum probability threshold sampling.
- **Repetition Penalty (`--repeat-penalty`)** & **Repeat Last N (`--repeat-last-n`)**: Prevent degenerative looping and repetition.
- **Max Generation Tokens (`-n`)**: Unlimited (`-1`) or custom token cutoff.

---

## Requirements

- **Operating System**: Windows 10 or Windows 11 (x64)
- **Runtime**: [.NET 10.0](https://dotnet.microsoft.com/download) Windows Desktop Runtime
- **Backend**: [`llama.cpp`](https://github.com/ggml-org/llama.cpp/releases) (`llama-cli.exe`)

---

## Building from Source

```bash
git clone https://github.com/r0bledas/eLlama.git
cd eLlama
dotnet build -c Release
```

The output executable will be created at `bin\Release\net10.0-windows\eLlama.exe`.

---

## License

MIT License.
