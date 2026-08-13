/* SPDX-License-Identifier: Apache-2.0 */
#include "lcd_dma.h"

static inline void lcd_dma_write32(volatile unsigned long *addr, unsigned long val)
{
    *addr = val;
    asm volatile("" ::: "memory");
}

static inline unsigned long lcd_dma_read32(volatile unsigned long *addr)
{
    return *addr;
}

void __attribute__((weak)) lcd_dma_cache_clean_range(void* addr, unsigned int bytes)
{
    (void)addr;
    (void)bytes;
}

int lcd_dma_set_region(unsigned long fb_addr, unsigned int pixel_count)
{
    unsigned long bytes = (unsigned long)pixel_count * LCD_DMA_BYTES_PER_PIXEL;

    if (fb_addr == 0 || pixel_count == 0)
        return LCD_DMA_ERR_PARAM;

    if ((fb_addr & LCD_DMA_ADDR_ALIGN_MASK) != 0)
        return LCD_DMA_ERR_ALIGNMENT;

    lcd_dma_cache_clean_range((void*)fb_addr, bytes);

    lcd_dma_write32((volatile unsigned long *)CONFREG_CR0, fb_addr);
    lcd_dma_write32((volatile unsigned long *)CONFREG_CR1, (unsigned long)pixel_count);
    return LCD_DMA_OK;
}

int lcd_dma_start(unsigned int cr2_value)
{
    unsigned long cr2;

    if ((lcd_dma_read32((volatile unsigned long *)CONFREG_CR2) & LCD_DMA_START_BIT_MASK) != 0)
        return LCD_DMA_ERR_START_BUSY;

    cr2 = ((unsigned long)cr2_value) & ~LCD_DMA_START_BIT_MASK;
    cr2 |= LCD_DMA_START_BIT_MASK;

    lcd_dma_write32((volatile unsigned long *)CONFREG_CR2, cr2);
    lcd_dma_write32((volatile unsigned long *)CONFREG_CR2, ((unsigned long)cr2_value) & ~LCD_DMA_START_BIT_MASK);
    return LCD_DMA_OK;
}

int lcd_dma_start_frame(unsigned long fb_addr, unsigned int pixel_count, unsigned int cr2_value)
{
    int ret;

    ret = lcd_dma_set_region(fb_addr, pixel_count);
    if (ret != LCD_DMA_OK)
        return ret;

    return lcd_dma_start(cr2_value);
}
