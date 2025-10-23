# Makefile -- Orchestrate the ECL → C → WebAssembly toolchain

PROJECT := clwasm
PROJECT_ROOT := $(abspath .)
BUILD_DIR := build
WASM_DIR := wasm

ECL ?= ecl
ECLFLAGS ?= --norc

# When cross-compiling with Emscripten, provide the SDK tool names.
EMCC ?= emcc
EMAR ?= emar
EMRANLIB ?= emranlib

# Location of the ECL headers and libraries that were themselves built with Emscripten.
# Adjust this to the prefix you used when you configured & installed ECL under emsdk.
ECL_WASM_PREFIX ?= $(PROJECT_ROOT)/third_party/ecl-wasm-examples
ECL_INCLUDE := $(ECL_WASM_PREFIX)/include
ECL_RUNTIME_LIBS := $(ECL_WASM_PREFIX)/libecl.a \
	$(ECL_WASM_PREFIX)/libeclgc.a \
	$(ECL_WASM_PREFIX)/libeclgmp.a

EMCC_COMMON_FLAGS ?= -O2 -sASYNCIFY -sASYNCIFY_STACK_SIZE=262144 -sSUPPORT_LONGJMP=1 -sMODULARIZE=1 -sEXPORT_ES6=1 -sENVIRONMENT=web,worker -sEXIT_RUNTIME=1 -sALLOW_MEMORY_GROWTH=1 -sERROR_ON_UNDEFINED_SYMBOLS=0
EMCC_LINK_FLAGS ?= -sEXPORTED_RUNTIME_METHODS='["ccall","cwrap"]' -sDEFAULT_LIBRARY_FUNCS_TO_INCLUDE='["__wasm_setjmp","__wasm_longjmp","__wasm_setjmp_test","emscripten_longjmp"]'

STATIC_LIB := $(BUILD_DIR)/lib$(PROJECT).a
ENTRY_JS := $(WASM_DIR)/$(PROJECT).js
ENTRY_WASM := $(WASM_DIR)/$(PROJECT).wasm

LISP_SOURCES := $(wildcard src/*.lisp)

.PHONY: all clean wasm run

all: $(ENTRY_JS)


$(STATIC_LIB): $(LISP_SOURCES) scripts/build.lisp | $(BUILD_DIR)
	@printf "[make] translating Lisp sources with ECL\n"
	ECL_KEEP_TEMP_FILES=1 $(ECL) $(ECLFLAGS) --load scripts/build.lisp

$(ENTRY_JS): $(STATIC_LIB) host/driver.c | $(WASM_DIR)
	@printf "[make] linking WebAssembly module\n"
	$(EMCC) $(EMCC_COMMON_FLAGS) $(EMCC_LINK_FLAGS) \
		-I$(ECL_INCLUDE) -I$(BUILD_DIR) -I$(PROJECT_ROOT) \
		host/driver.c \
		$(BUILD_DIR)/package.c $(BUILD_DIR)/core.c \
		$(ECL_RUNTIME_LIBS) \
		-o $(ENTRY_JS)

$(BUILD_DIR):
	mkdir -p $@

$(WASM_DIR):
	mkdir -p $@

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(WASM_DIR)/*.js $(WASM_DIR)/*.wasm $(WASM_DIR)/*.wasm.map

# Helper target that runs a tiny static file server via python for local testing.
run: $(ENTRY_JS)
	@printf "Serving wasm artifacts from $(WASM_DIR) (Ctrl+C to stop)\n"
	python3 -m http.server --directory $(WASM_DIR) 8080
