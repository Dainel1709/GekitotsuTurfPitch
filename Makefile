# ==============================================================================
# Makefile para Gekitotsu Turf Pitch (GDExtension C++17)
# Compatible con Windows (MinGW/MSYS2/Clang) y macOS (Apple Clang/LLVM)
# ==============================================================================

# Nombre del módulo
TARGET_NAME := libgekitotsu

# Detección del Sistema Operativo
ifeq ($(OS),Windows_NT)
    PLATFORM := windows
    TARGET_EXT := .dll
    BIN_TARGET := bin/$(TARGET_NAME).windows.release.x86_64$(TARGET_EXT)
    BIN_TARGET_DEBUG := bin/$(TARGET_NAME).windows.debug.x86_64$(TARGET_EXT)
    CXX ?= g++
    SHARED_FLAGS := -shared -Wl,--out-implib,bin/$(TARGET_NAME).a
    MKDIR_P = if not exist $(subst /,\,$(1)) mkdir $(subst /,\,$(1))
    RM = del /Q /F
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Darwin)
        PLATFORM := macos
        TARGET_EXT := .dylib
        BIN_TARGET := bin/$(TARGET_NAME).macos.release.universal$(TARGET_EXT)
        BIN_TARGET_DEBUG := bin/$(TARGET_NAME).macos.debug.universal$(TARGET_EXT)
        CXX ?= clang++
        SHARED_FLAGS := -dynamiclib -undefined dynamic_lookup
        MKDIR_P = mkdir -p $(1)
        RM = rm -f
    else
        PLATFORM := linux
        TARGET_EXT := .so
        BIN_TARGET := bin/$(TARGET_NAME).linux.release.x86_64$(TARGET_EXT)
        BIN_TARGET_DEBUG := bin/$(TARGET_NAME).linux.debug.x86_64$(TARGET_EXT)
        CXX ?= g++
        SHARED_FLAGS := -shared
        MKDIR_P = mkdir -p $(1)
        RM = rm -f
    endif
endif

# Banderas de compilación C++17
CXXFLAGS := -std=c++17 -fPIC -Wall -Wextra -Wno-unused-parameter
INCLUDES := -Isrc -Isrc/core -Isrc/designar -Isrc/story -Isrc/physics

# Rutas de salida para objetos
BUILD_DIR := build/$(PLATFORM)
SOURCES := $(wildcard src/*.cpp) \
           $(wildcard src/core/*.cpp) \
           $(wildcard src/designar/*.cpp) \
           $(wildcard src/story/*.cpp) \
           $(wildcard src/physics/**/*.cpp)

OBJECTS := $(patsubst src/%.cpp, $(BUILD_DIR)/%.o, $(SOURCES))

.PHONY: all release debug clean info

all: release

release: CXXFLAGS += -O3 -DNDEBUG
release: $(BIN_TARGET)

debug: CXXFLAGS += -g -O0 -DDEBUG_ENABLED
debug: $(BIN_TARGET_DEBUG)

$(BIN_TARGET): $(OBJECTS)
	@$(call MKDIR_P,bin)
	$(CXX) $(SHARED_FLAGS) -o $@ $(OBJECTS)
	@echo "==> Binario compilado exitosamente: $@"

$(BIN_TARGET_DEBUG): $(OBJECTS)
	@$(call MKDIR_P,bin)
	$(CXX) $(SHARED_FLAGS) -o $@ $(OBJECTS)
	@echo "==> Binario Debug compilado exitosamente: $@"

$(BUILD_DIR)/%.o: src/%.cpp
	@$(call MKDIR_P,$(dir $@))
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	@echo "Limpiando artefactos de compilación..."
	-$(RM) $(subst /,\,$(BUILD_DIR))\*.o 2>nul || true
	-$(RM) $(subst /,\,$(BIN_TARGET)) 2>nul || true
	-$(RM) $(subst /,\,$(BIN_TARGET_DEBUG)) 2>nul || true

info:
	@echo "Plataforma detectada : $(PLATFORM)"
	@echo "Compilador CXX       : $(CXX)"
	@echo "Destino Release      : $(BIN_TARGET)"
	@echo "Destino Debug        : $(BIN_TARGET_DEBUG)"
