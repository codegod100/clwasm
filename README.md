# clwasm: ECL → C → WebAssembly demo

This repository shows how to take a tiny Embeddable Common Lisp (ECL) project,
keep the generated C sources, and use the Emscripten toolchain to turn the
result into a WebAssembly module.

The flow looks like this:

```
Common Lisp (src/*.lisp)
        │  ECL compiler (scripts/build.lisp)
        ▼
Generated C/H (build/)
  │
Generated .data tables (build/)
  │  emcc + host/driver.c + libecl runtime
        ▼
wasm/clwasm.js + wasm/clwasm.wasm
```

## Prerequisites

You need a native ECL build to run the compilation driver, plus an Emscripten
SDK capable of producing WebAssembly artefacts. This repository vendors the
wasm-ready ECL runtime objects from
[`sgithens/ecl-wasm-examples`](https://github.com/sgithens/ecl-wasm-examples)
under `third_party/ecl-wasm-examples/` alongside the necessary Boehm GC, GMP,
and libatomic_ops headers. That means you can build immediately, but you can
also regenerate the runtime locally by following the optional step below.

1. **ECL (host build)** – install from your distro or compile from source. The
  `ecl` binary must be on `PATH`.
2. **Emscripten** – install the SDK from <https://emscripten.org/> and activate
  the environment:
  ```fish
  source $HOME/emsdk/emsdk_env.fish
  ```
3. **ECL (wasm build, optional)** – to refresh the vendored runtime, configure
  ECL with Emscripten (e.g. `emconfigure ./configure --host=wasm32-unknown-emscripten --disable-threads --disable-shared`), run `emmake make install`, and
  copy the resulting `libecl{,gc,gmp}.a` plus headers into
  `third_party/ecl-wasm-examples/`. The bundled configuration disables thread
  support because wasm32 lacks the atomic primitives ECL expects.

## Building the demo

Once the prerequisites are in place:

```fish
cd /home/nandi/proj/clwasm
make
```

The build performs two phases:

1. `scripts/build.lisp` asks ECL to compile `src/package.lisp` and
  `src/core.lisp` with `:system-p t`, keeping the generated `.c`, `.h`, and
  `.data` files under `build/`. It also assembles a host static archive
  `build/libclwasm.a` whose init symbol is fixed to `init_clwasm` for native
  experimentation.
2. `emcc` compiles the generated C sources together with `host/driver.c` and
  links them against the vendored `libecl{,gc,gmp}.a` runtime to emit
  `wasm/clwasm.js` + `wasm/clwasm.wasm`.

Intermediate artefacts:

- `build/*.c`, `build/*.h`, and `build/*.data` are the translation units and
  constant tables emitted by ECL.
- `build/*.o` are host objects emitted during translation (handy for native
  tests, unused in the wasm link step).
- `build/libclwasm.a` bundles the Lisp code for native experimentation (host
  architecture).

## Trying it out

To run the module in a browser during development:

```fish
make run
```

This starts `python3 -m http.server` on port 8080 serving `wasm/`. Open
<http://localhost:8080/> in a browser with the developer console visible. Press
"Run" to invoke the wasm module; the Common Lisp output is printed to the
console because the sample host simply writes to standard output.

For command-line testing you can execute the generated JS harness (Node ≥ 20):

```fish
node --experimental-wasm-modules wasm/clwasm.js 20
```

This mirrors the behaviour of the native driver and prints a short Fibonacci
sequence.

## Key files

- `src/` – Common Lisp sources (`clwasm` package and exported API)
- `scripts/build.lisp` – instructs ECL to keep the generated C/H files and build
  a static archive with a stable init symbol
- `host/driver.c` – tiny C wrapper that boots/shuts down ECL and calls the
  exported Lisp entry point
- `Makefile` – wires the steps together and links with Emscripten
- `wasm/index.html` – minimal UI to load the resulting module in a browser

## Tips & troubleshooting

- Set `CLWASM_EMCC_FLAGS` to append extra compiler flags (e.g. optimisation or
  warnings) when ECL invokes `emcc` during the Lisp compilation phase.
- If the build cannot locate `libecl.a`, export `ECL_WASM_PREFIX` to the prefix
  you used during the wasm installation step, or edit the Makefile.
- To inspect the raw C translation units that ECL emits, look under
  `build/*.c`. They match the `compile-file :c-file` output described in the ECL
  manual (§4.7.1 *The compiler translates to C*).
- When iterating quickly you can delete `build/*.o` to force a clean recompile
  without wiping the retained `.c`/`.h` files.
