# Large JSON Viewer v1.0.0

## Initial Release

A high-performance JSON viewer designed to handle files ranging from kilobytes to multi-gigabyte sizes, built with Lazarus/Free Pascal and optimized with SIMD (AVX2) instructions.

---

### Core Engine

- **Memory-Mapped File I/O** — Uses a 256 MB sliding window to stream files of virtually any size without loading them entirely into RAM.
- **Streaming JSON Parser** — Single-pass parser with an explicit stack (max depth 65 536) that materializes nodes on demand rather than building a full DOM upfront.
- **SIMD-Accelerated Scanning** — AVX2-optimized routines for string skipping and whitespace scanning, with automatic scalar fallback on unsupported CPUs. Runtime CPU feature detection via CPUID.
- **On-Demand Node Materialization** — Nodes are only expanded when the user opens them, paired with an LRU cache (default 100 MB) to keep recently viewed data instantly accessible.
- **Encoding Support** — Automatic BOM detection and transparent handling of UTF-8, UTF-16LE, and UTF-16BE input.

### User Interface

- **Virtual Tree View** — Lazy-loaded, collapsible tree with auto-grouping that can render millions of child nodes without freezing.
- **File Size Tiers** — Adaptive behavior across four tiers: Small (< 10 MB), Medium (< 100 MB), Large (< 1 GB), and Huge (> 1 GB).
- **Architecture-Aware Title Bar** — Displays the detected CPU optimization level (AVX2 / ARM NEON / x86 Scalar).

### Search & Navigation

- **Full-Text Search** — Plain-text and regular expression modes with case-sensitive toggle. Search scopes: keys only, values only, or both.
- **JSONPath Support** — Query nodes using standard JSONPath expressions.

### Export

Export selected nodes or the entire document to:
- JSON (as-is / minified / beautified)
- XML (minified / beautified)
- CSV
- YAML
- TOML

### Additional Features

- **URL Loading** — Open remote JSON files directly via HTTP/HTTPS.
- **Windows File Association** — Optional `.json` file type registration during installation.
- **Auto-Refresh** — Watches the open file for changes and reloads automatically.
- **Always-on-Top Mode** — Keep the viewer above other windows.
- **NSIS Installer** — One-click Windows x64 setup with optional file association.

### System Requirements

- **OS:** Windows 7 SP1 or later (x64)
- **CPU:** x86-64 (AVX2 recommended for best performance)
- **RAM:** 512 MB minimum; 2 GB+ recommended for files over 1 GB
