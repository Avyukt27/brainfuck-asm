ASM := nasm
ASM_FLAGS := -f elf64 -F dwarf -g
LD := ld

SRC_DIR := src
BUILD_DIR := build
TARGET := $(BUILD_DIR)/main

SRC := $(SRC_DIR)/main.asm
OBJ := $(BUILD_DIR)/main.o

all: clean build

build: $(OBJ)
	@mkdir -p $(BUILD_DIR)
	$(LD) $(OBJ) -o $(TARGET)

$(OBJ): $(SRC)
	@mkdir -p $(BUILD_DIR)
	$(ASM) $(ASM_FLAGS) $(SRC) -o $(OBJ)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
