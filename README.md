# eLlama

**eLlama** is a fast, native Windows desktop manager and launcher for local GGUF large language models, powered directly by [`llama.cpp`](https://github.com/ggml-org/llama.cpp).

Unlike traditional local runners that duplicate model weights into internal blob layers and eat gigabytes of disk space, eLlama executes `.gguf` files directly in place with **zero file copying**, **zero background daemons**, and **zero overhead**.

---

## Key Features

- **Zero-Copy In-Place Execution**: Streams `.gguf` models directly from your folder without duplicating disk space.
- **100% Portable Distribution**: Can run entirely standalone from any folder, external SSD, or USB flash drive without installation.
- **Cross-GPU Vulkan Acceleration**: Out-of-the-box hardware acceleration across Nvidia, AMD Radeon, and Intel GPUs without needing CUDA drivers or toolkits.
- **Built-in llama.cpp Updater**: Download or update to the latest official `llama.cpp` Vulkan release directly from the Settings interface with one click.
- **Model Catalog Exporter**: Export your entire local model catalog and metadata to CSV, JSON, Markdown, or Plain Text.
- **Fast Instant Search**: Real-time filtering across model names, publishers, quantization types, and filenames.
- **Vision Projector Auto-Filter**: Automatically recognizes and isolates vision projector files (`mmproj`) so your model list remains clean.
- **Interactive Terminal Chat**: Launch models into full interactive multi-turn conversations with a single double-click or by hitting Enter.
- **Numerical Sorting**: One-click sorting by file size (calculated numerically by bytes), model name, quant, or publisher.

---

## Portable Distribution Layout

eLlama supports a completely self-contained, portable folder structure:

```text
eLlama-Portable/
├── eLlama.exe               # Self-contained launcher (no .NET runtime install required)
├── settings.json            # Portable local settings (stored alongside eLlama.exe)
├── models/                  # Your .gguf model library
│   └── Llama-3-8B-Instruct.gguf
└── llama.cpp/               # llama.cpp binaries with Vulkan hardware acceleration
    ├── llama-cli.exe
    ├── ggml-vulkan.dll
    └── ... (supporting libraries)
```

When placed in this structure, eLlama automatically resolves all paths relatively (`models` and `llama.cpp\llama-cli.exe`), meaning you can move the folder anywhere or run it from a USB drive on any Windows PC.

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
- **Runtime**: None required (bundled runtime in both Installer and Portable distributions); or [.NET 10.0](https://dotnet.microsoft.com/download) Windows Desktop Runtime for source builds.
- **Backend**: Pre-bundled [`llama.cpp`](https://github.com/ggml-org/llama.cpp/releases) (`llama-cli.exe`) with cross-GPU Vulkan acceleration.

---

## Installation & Downloads

Official releases are distributed in two clean options:
1. **Windows Installer (`eLlama-Setup-v1.1.0.exe`)**:
   - Modern, per-user setup (no administrator UAC prompts required).
   - Installs to `%LocalAppData%\Programs\eLlama`.
   - Creates Start Menu and Desktop shortcuts.
   - Includes full uninstaller registered in Windows Settings.
2. **Portable Edition (`eLlama-Portable-v1.1.0-win-x64.zip`)**:
   - Zero-installation zip package.
   - Extract to any folder, external SSD, or USB drive and launch immediately.

---

## Building from Source

```bash
git clone https://github.com/r0bledas/eLlama.git
cd eLlama
dotnet build -c Release
```

To build a self-contained portable release:
```bash
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -o ./PortableRelease
```

To compile the Windows installer (requires Inno Setup 6):
```bash
iscc installer.iss
```

---

## Credits & Acknowledgements

eLlama is built on the shoulders of giants in the open-source and local AI community. Special thanks and attribution to:

- **[Georgi Gerganov](https://github.com/ggerganov) & the [llama.cpp community](https://github.com/ggml-org/llama.cpp)**: For developing the incredible `llama.cpp` and `ggml` engines that power high-performance local LLM inference across millions of devices.
- **[The Khronos Group Inc.](https://www.vulkan.org/)**: For the cross-platform Vulkan API enabling vendor-neutral GPU acceleration.
- **[The LLVM Project](https://llvm.org/)**: For the high-performance OpenMP multi-threading runtime.
- **[.NET Foundation & Microsoft](https://dotnet.microsoft.com/)**: For the .NET 10 desktop runtime and Windows Forms application platform.

---

## License & Legal Notices

- **eLlama**: Licensed under the [MIT License](LICENSE). Copyright (c) 2026 Raudel.
- **Third-Party Components & Dependencies**: All bundled or interfaced third-party tools (including `llama.cpp`, `ggml`, `libomp.dll`, and Vulkan) are distributed under their respective open-source licenses. For complete copyright notices and license texts, see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).



