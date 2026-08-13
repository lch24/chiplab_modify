#include <stdint.h>
#include <stdio.h>

unsigned long UART_BASE = 0xbfe001e0;
unsigned long CONFREG_UART_BASE = 0xbfafff10;
unsigned long CONFREG_TIMER_BASE = 0xbfafe000;
unsigned long CONFREG_CLOCKS_PER_SEC = 100000000L;
unsigned long CORE_CLOCKS_PER_SEC = 33000000L;

typedef int (*entry_t)(void);

static void write_target(uint32_t *target)
{
    /*
     * addi.w a0, zero, 0x5a
     * jirl   zero, ra, 0
     */
    target[0] = 0x02816804u;
    target[1] = 0x4c000020u;
}

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;

    volatile uint32_t *target = (volatile uint32_t *)0xa0200000u;
    write_target((uint32_t *)target);

    printf("before jump: %08x %08x\n", target[0], target[1]);

#ifdef USE_BARRIER
    __asm__ volatile("dbar 0\nibar 0" ::: "memory");
#endif

    int ret = ((entry_t)0xa0200000u)();
    printf("after jump: %08x\n", ret);

    return ret == 0x5a ? 0 : 1;
}
