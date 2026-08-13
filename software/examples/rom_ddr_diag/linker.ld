ENTRY(_start)
SECTIONS
{
    . = IMAGE_BASE;
    .text : {
        *(.text*)
        *(.rodata*)
    }
}
