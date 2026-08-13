CROSS_COMPILE ?= loongarch32r-linux-gnusf-
CC := $(CROSS_COMPILE)gcc
LD := $(CROSS_COMPILE)ld
OBJCOPY := $(CROSS_COMPILE)objcopy
OBJDUMP := $(CROSS_COMPILE)objdump

AFLAGS := -fno-pic -pipe
LDFLAGS := -static -T linker.ld

all: way_mismatch.elf way_correct.elf obj/rom.vlog obj/rom_correct.vlog

obj:
	mkdir -p obj

obj/way_mismatch.o: start.S | obj
	$(CC) $(AFLAGS) -c $< -o $@

obj/way_correct.o: start.S | obj
	$(CC) $(AFLAGS) -DFULL_GEOMETRY -c $< -o $@

way_mismatch.elf: obj/way_mismatch.o linker.ld
	$(LD) $(LDFLAGS) obj/way_mismatch.o -o $@
	$(OBJDUMP) -d $@ > obj/way_mismatch.s

way_correct.elf: obj/way_correct.o linker.ld
	$(LD) $(LDFLAGS) obj/way_correct.o -o $@
	$(OBJDUMP) -d $@ > obj/way_correct.s

obj/way_mismatch.bin: way_mismatch.elf | obj
	$(OBJCOPY) -O binary $< $@

obj/way_correct.bin: way_correct.elf | obj
	$(OBJCOPY) -O binary $< $@

obj/rom.vlog: obj/way_mismatch.bin
	{ printf '@1c000000\n'; od -An -tx1 -v $< | tr ' ' '\n' | sed '/^$$/d'; } > $@

obj/rom_correct.vlog: obj/way_correct.bin
	{ printf '@1c000000\n'; od -An -tx1 -v $< | tr ' ' '\n' | sed '/^$$/d'; } > $@

clean:
	rm -rf obj way_mismatch.elf way_correct.elf

.PHONY: all clean
