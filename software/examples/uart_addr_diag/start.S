.text
.globl _start
_start:
#ifdef SET_DMW
    li.w      $r12, 0xa0000001
    csrwr     $r12, 0x180
    li.w      $r12, 0x00000001
    csrwr     $r12, 0x181
    li.w      $r12, 0x10
    li.w      $r13, 0x18
    csrxchg   $r12, $r13, 0x0
#endif

    li.w      $r12, UART_BASE

wait0:
    ld.b      $r13, $r12, 5
    andi      $r13, $r13, 0x20
    beq       $r13, $r0, wait0
    li.w      $r13, MSG0
    st.b      $r13, $r12, 0

wait1:
    ld.b      $r13, $r12, 5
    andi      $r13, $r13, 0x20
    beq       $r13, $r0, wait1
    li.w      $r13, MSG1
    st.b      $r13, $r12, 0

wait2:
    ld.b      $r13, $r12, 5
    andi      $r13, $r13, 0x20
    beq       $r13, $r0, wait2
    li.w      $r13, 0x0a
    st.b      $r13, $r12, 0

done:
    b         done
