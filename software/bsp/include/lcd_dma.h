/* SPDX-License-Identifier: Apache-2.0 */
#ifndef __LCD_DMA_H
#define __LCD_DMA_H

#ifdef __cplusplus
extern "C" {
#endif

#ifndef CONFREG_CR0
#define CONFREG_CR0            0xbfaf8000ul
#endif

#ifndef CONFREG_CR1
#define CONFREG_CR1            0xbfaf8010ul
#endif

#ifndef CONFREG_CR2
#define CONFREG_CR2            0xbfaf8020ul
#endif

#define LCD_DMA_START_BIT_MASK 0x1ul
#define LCD_DMA_ADDR_ALIGN_MASK 0x7ul
#define LCD_DMA_BYTES_PER_PIXEL 2u

#define LCD_DMA_OK            0
#define LCD_DMA_ERR_PARAM    -1
#define LCD_DMA_ERR_ALIGNMENT -2
#define LCD_DMA_ERR_START_BUSY -3

/* 配置DMA像素源基址与像素数量（RGB565每像素2字节） */
int lcd_dma_set_region(unsigned long fb_addr, unsigned int pixel_count);

/* 触发一次DMA启动。会拉高CR2[0]后清零，避免反复重复触发 */
int lcd_dma_start(unsigned int cr2_value);

/* 一步到位启动：先配置CR0/CR1，再触发CR2 */
int lcd_dma_start_frame(unsigned long fb_addr, unsigned int pixel_count, unsigned int cr2_value);

/* 默认启动入口：仅使用CR2[0]作为start位（兼容现有RTL约定） */
static inline int lcd_dma_start_frame_rgb565(unsigned long fb_addr, unsigned int pixel_count)
{
    return lcd_dma_start_frame(fb_addr, pixel_count, (unsigned int)LCD_DMA_START_BIT_MASK);
}

/* 若你的CPU有cache且DMA读内存前未自动回写，可在工程中提供强符号覆盖 */
void __attribute__((weak)) lcd_dma_cache_clean_range(void* addr, unsigned int bytes);

#ifdef __cplusplus
}
#endif

#endif /* __LCD_DMA_H */
