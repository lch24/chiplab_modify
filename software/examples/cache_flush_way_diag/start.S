    .section .text
    .global _start

# The CPU uses 64B lines and 4 ways. Legacy OpenLA500 boot firmware uses
# 16B-line, 2-way geometry. This program creates a dirty target line in
# way 3 and then runs either the legacy sweep or a native-geometry sweep.
# Before the hardware compatibility fix the legacy build selected OLD. Both
# builds must select NEW after index CACOP operates on the complete set.

#define TARGET_PA       0x00200000
#define TARGET_VA       0xa0200000
#define CONFLICT0_VA    0xa0201000
#define CONFLICT1_VA    0xa0202000
#define CONFLICT2_VA    0xa0203000

_start:
    la.local  $r16, old_payload_start
    la.local  $r17, old_payload_end
    li.w      $r18, TARGET_PA
copy_old_loop:
    ld.w      $r12, $r16, 0
    st.w      $r12, $r18, 0
    addi.w    $r16, $r16, 4
    addi.w    $r18, $r18, 4
    bltu      $r16, $r17, copy_old_loop
    dbar      0
    ibar      0

    li.w      $r12, 0x00000011
    csrwr     $r12, 0x180
    li.w      $r12, 0xa0000011
    csrwr     $r12, 0x181
    li.w      $r12, 0x18
    li.w      $r13, 0x10
    csrxchg   $r13, $r12, 0x0

    # Empty set 0 after committing the old target. The following three
    # conflicts then occupy ways 0..2 and the new target occupies way 3.
    li.w      $r12, 0
    cacop     0x09, $r12, 0
    cacop     0x09, $r12, 1
    cacop     0x09, $r12, 2
    cacop     0x09, $r12, 3
    dbar      0

    li.w      $r12, CONFLICT0_VA
    li.w      $r13, 0x11111111
    st.w      $r13, $r12, 0
    li.w      $r12, CONFLICT1_VA
    li.w      $r13, 0x22222222
    st.w      $r13, $r12, 0
    li.w      $r12, CONFLICT2_VA
    li.w      $r13, 0x33333333
    st.w      $r13, $r12, 0

    la.local  $r16, new_payload_start
    la.local  $r17, new_payload_end
    li.w      $r18, TARGET_VA
copy_new_loop:
    ld.w      $r12, $r16, 0
    st.w      $r12, $r18, 0
    addi.w    $r16, $r16, 4
    addi.w    $r18, $r18, 4
    bltu      $r16, $r17, copy_new_loop

    dbar      0

#ifdef FULL_GEOMETRY
    li.w      $r22, 0
    cacop     0x09, $r22, 0
    cacop     0x09, $r22, 1
    cacop     0x09, $r22, 2
    cacop     0x09, $r22, 3
    cacop     0x00, $r22, 0
    cacop     0x00, $r22, 1
    cacop     0x00, $r22, 2
    cacop     0x00, $r22, 3
#else
    li.w      $r22, 0
    cacop     0x09, $r22, 0
    cacop     0x09, $r22, 1
    cacop     0x00, $r22, 0
    cacop     0x00, $r22, 1
#endif

    dbar      0
    li.w      $r18, TARGET_VA
    jirl      $r0, $r18, 0

should_not_return:
    b         should_not_return

    .align 2
old_payload_start:
    li.w      $r12, 0xbfafff10
    li.w      $r13, 'O'
    st.w      $r13, $r12, 0
    li.w      $r13, 'L'
    st.w      $r13, $r12, 0
    li.w      $r13, 'D'
    st.w      $r13, $r12, 0
    li.w      $r13, '\n'
    st.w      $r13, $r12, 0
old_loop:
    b         old_loop
old_payload_end:

    .align 2
new_payload_start:
    li.w      $r12, 0xbfafff10
    li.w      $r13, 'N'
    st.w      $r13, $r12, 0
    li.w      $r13, 'E'
    st.w      $r13, $r12, 0
    li.w      $r13, 'W'
    st.w      $r13, $r12, 0
    li.w      $r13, '\n'
    st.w      $r13, $r12, 0
new_loop:
    b         new_loop
new_payload_end:
