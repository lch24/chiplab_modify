.section .text
.global _start

#ifndef UART_BASE
#define UART_BASE 0xbfe001e0
#endif
#ifndef ROM_BASE
#define ROM_BASE  0x1c000000
#endif
#ifndef ROM_END
#define ROM_END   0x1c052528
#endif
#ifndef ROM_TAIL
#define ROM_TAIL  0x1c052520
#endif
#ifndef DST_BYTE
#define DST_BYTE  0xa0400000
#endif
#ifndef DST_WORD
#define DST_WORD  0xa0500000
#endif
#ifndef DDR_PAT
#define DDR_PAT   0xa0600000
#endif

_start:
    li.w      $r12, 0xa0000001
    csrwr     $r12, 0x180
    li.w      $r12, 0x00000001
    csrwr     $r12, 0x181
    li.w      $r12, 0x10
    li.w      $r13, 0x18
    csrxchg   $r12, $r13, 0x0
    dbar      0
    ibar      0

    li.w      $r20, UART_BASE

    la.local  $r4, msg_banner
    bl        print_str

    la.local  $r4, msg_rom0
    bl        print_str
    li.w      $r16, ROM_BASE
    ld.w      $r4, $r16, 0
    bl        print_hex32
    bl        print_crlf

    la.local  $r4, msg_rom_tail
    bl        print_str
    li.w      $r16, ROM_TAIL
    ld.w      $r4, $r16, 0
    bl        print_hex32
    bl        print_crlf

    la.local  $r4, msg_pat
    bl        print_str
    li.w      $r16, DDR_PAT
    li.w      $r5, 0x11223344
    st.w      $r5, $r16, 0
    li.w      $r5, 0xa5
    st.b      $r5, $r16, 2
    dbar      0
    ld.w      $r4, $r16, 0
    bl        print_hex32
    bl        print_crlf

    la.local  $r4, msg_bcopy
    bl        print_str
    li.w      $r16, ROM_BASE
    li.w      $r17, DST_BYTE
    li.w      $r18, ROM_END
byte_copy_loop:
    ld.bu     $r5, $r16, 0
    st.b      $r5, $r17, 0
    addi.w    $r16, $r16, 1
    addi.w    $r17, $r17, 1
    bltu      $r16, $r18, byte_copy_loop
    dbar      0

    li.w      $r16, ROM_BASE
    li.w      $r17, DST_BYTE
    li.w      $r18, ROM_END
byte_cmp_loop:
    ld.bu     $r5, $r16, 0
    ld.bu     $r6, $r17, 0
    bne       $r5, $r6, byte_fail
    addi.w    $r16, $r16, 1
    addi.w    $r17, $r17, 1
    bltu      $r16, $r18, byte_cmp_loop
    la.local  $r4, msg_pass
    bl        print_str
    b         word_test

byte_fail:
    la.local  $r4, msg_fail
    bl        print_str
    b         print_mismatch

word_test:
    la.local  $r4, msg_wcopy
    bl        print_str
    li.w      $r16, ROM_BASE
    li.w      $r17, DST_WORD
    li.w      $r18, ROM_END
word_copy_loop:
    ld.w      $r5, $r16, 0
    st.w      $r5, $r17, 0
    addi.w    $r16, $r16, 4
    addi.w    $r17, $r17, 4
    bltu      $r16, $r18, word_copy_loop
    dbar      0

    li.w      $r16, ROM_BASE
    li.w      $r17, DST_WORD
    li.w      $r18, ROM_END
word_cmp_loop:
    ld.bu     $r5, $r16, 0
    ld.bu     $r6, $r17, 0
    bne       $r5, $r6, word_fail
    addi.w    $r16, $r16, 1
    addi.w    $r17, $r17, 1
    bltu      $r16, $r18, word_cmp_loop
    la.local  $r4, msg_pass
    bl        print_str
    b         done

word_fail:
    la.local  $r4, msg_fail
    bl        print_str
    b         print_mismatch

print_mismatch:
    la.local  $r4, msg_src
    bl        print_str
    move      $r4, $r16
    bl        print_hex32
    la.local  $r4, msg_dst
    bl        print_str
    move      $r4, $r17
    bl        print_hex32
    la.local  $r4, msg_sv
    bl        print_str
    move      $r4, $r5
    bl        print_hex8
    la.local  $r4, msg_dv
    bl        print_str
    move      $r4, $r6
    bl        print_hex8
    bl        print_crlf

done:
    la.local  $r4, msg_done
    bl        print_str
spin:
    b         spin

print_str:
    ld.bu     $r5, $r4, 0
    beq       $r5, $r0, print_str_ret
    addi.w    $r4, $r4, 1
    b         uart_put_r5
print_str_next:
    b         print_str
print_str_ret:
    jirl      $r0, $r1, 0

print_crlf:
    li.w      $r5, 0x0d
    b         uart_put_r5_cr
print_crlf_lf:
    li.w      $r5, 0x0a
    b         uart_put_r5_ret

print_hex32:
    move      $r8, $r4
    li.w      $r7, 28
hex32_loop:
    srl.w     $r5, $r8, $r7
    andi      $r5, $r5, 0xf
    sltui     $r6, $r5, 10
    beq       $r6, $r0, hex32_alpha
    addi.w    $r5, $r5, 0x30
    b         hex32_emit
hex32_alpha:
    addi.w    $r5, $r5, 0x37
hex32_emit:
    b         uart_put_r5_hex32
hex32_next:
    addi.w    $r7, $r7, -4
    bge       $r7, $r0, hex32_loop
    jirl      $r0, $r1, 0

print_hex8:
    move      $r8, $r4
    li.w      $r7, 4
hex8_loop:
    srl.w     $r5, $r8, $r7
    andi      $r5, $r5, 0xf
    sltui     $r6, $r5, 10
    beq       $r6, $r0, hex8_alpha
    addi.w    $r5, $r5, 0x30
    b         hex8_emit
hex8_alpha:
    addi.w    $r5, $r5, 0x37
hex8_emit:
    b         uart_put_r5_hex8
hex8_next:
    addi.w    $r7, $r7, -4
    bge       $r7, $r0, hex8_loop
    jirl      $r0, $r1, 0

uart_put_r5:
    move      $r21, $r1
    la.local  $r22, print_str_next
    b         uart_put_common
uart_put_r5_cr:
    move      $r21, $r1
    la.local  $r22, print_crlf_lf
    b         uart_put_common
uart_put_r5_ret:
    move      $r21, $r1
    move      $r22, $r1
    b         uart_put_common
uart_put_r5_hex32:
    move      $r21, $r1
    la.local  $r22, hex32_next
    b         uart_put_common
uart_put_r5_hex8:
    move      $r21, $r1
    la.local  $r22, hex8_next
    b         uart_put_common

uart_put_common:
    li.w      $r23, 0x10000
uart_wait:
    ld.bu     $r24, $r20, 5
    andi      $r24, $r24, 0x20
    bne       $r24, $r0, uart_ready
    addi.w    $r23, $r23, -1
    bne       $r23, $r0, uart_wait
uart_ready:
    st.b      $r5, $r20, 0
    move      $r1, $r21
    jirl      $r0, $r22, 0

msg_banner:
    .asciz "\r\nRDDIAG\r\n"
msg_rom0:
    .asciz "ROM0="
msg_rom_tail:
    .asciz "TAIL="
msg_pat:
    .asciz "PAT="
msg_bcopy:
    .asciz "BCOPY "
msg_wcopy:
    .asciz "WCOPY "
msg_pass:
    .asciz "PASS\r\n"
msg_fail:
    .asciz "FAIL "
msg_src:
    .asciz "SRC="
msg_dst:
    .asciz " DST="
msg_sv:
    .asciz " SV="
msg_dv:
    .asciz " DV="
msg_done:
    .asciz "DONE\r\n"
