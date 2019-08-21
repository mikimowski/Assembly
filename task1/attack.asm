O_RDONLY	equ	0

SYS_READ	equ	0
SYS_OPEN	equ	2
SYS_EXIT	equ	60

BUFF_SIZE equ 4096 ; = 4096 bytes = 1024 segments from our file
MAGIC_CONST equ 68020

; r12, r13, r14, r15, rbx, rsp, rbp are callee-saved registers

; Def: "magic segment" - segment of numbers: 6, 8, 0, 2, 0

; r9 - stores address to read data from buffer in the next iteration
; r8 - Stores number of read bytes after SYS_READ
; r12d - Sum of read numbers modulo 2^32
; r13 - Stores file descriptor after it is successfully opened, otherwise not defined
; r14 - Flag is set iff magic_segment was read
; r15 - Flag is set iff number from interval (68020; 2^31) was read
; r10 - pointer to the next char to be read from magic sequence - points to the proper index in the magic_segment_arr
; - doesn't hold if magic_segment has already been read (flag in r14 is set)

section .data
    magic_segment_arr dd 6, 8, 0, 2, 0

section .bss
    buffer resb BUFF_SIZE

section .text
    global _start

_start:
    call _initiate
    call _open_file

    _parse_file_loop:
    call _read_next_portion
    cmp r8, 0 ; If end of file
    jz _exit_procedure
    call _parse_next_portion
    jmp _parse_file_loop


_initiate:
    xor r12, r12
    mov r14, 1111b
    mov r10, magic_segment_arr
    xor r15, r15

_open_file:
    ; Exactly one argument should've been given
    cmp qword [rsp + 8], 2; +8 because it's a function call (return address is on the top)
    jne _exit_with_one

    ; Tries to open file with given filename
    mov rax, SYS_OPEN
    mov rdi, [rsp + 24] ; rsp + 8 would be the program name
    mov rsi, O_RDONLY
    mov rdx, 0
    syscall

    cmp rax, 0  ; Check syscall feedback
    jl _exit_with_one ; Exit if error occured
    mov r13, rax ; Else memorize file descriptor

    ret

_read_next_portion:
    mov rax, SYS_READ
    mov rdi, r13
    mov rsi, buffer
    mov rdx, BUFF_SIZE
    syscall
    mov r8, rax
    mov r9, buffer ; Current place in the file ~ beginning of the next portion
    ret

_parse_next_portion:
    call _check_portion_length

    _parse_loop:
    ; Reads next number
    mov edi, dword [r9]
    add r9, 4 ; Move pointer in file forward by 4 bytes
    bswap edi ; Big-endian into Little-endian
    add r12, rdi ; Update sum of read numbers modulo 2^32

    ; Checks whether magic_const was read
    cmp edi, MAGIC_CONST
    je _exit_with_one

    ; Checks whether number from interval (68020; 2^31) was read
    cmp edi, MAGIC_CONST
    jle _update_magic_segment_status
    or r15b, 1 ; Set flag - number from interval was read

    _update_magic_segment_status:
    ; Update magic segment status - recently read number is stored in edi
    cmp r14, 1
    je _end_of_update_magic_segment_status

    cmp edi, [r10]
    je _inc_magic_segment_pointer
    jmp _reset_magic_segment_reading

    _reset_magic_segment_reading:
    mov r10, magic_segment_arr
    cmp edi, [r10]  ; In case we've read something like that: 686 ... - we've already started new magic_segment!
    je _inc_magic_segment_pointer
    jmp _end_of_update_magic_segment_status

    _inc_magic_segment_pointer:
    add r10, 4
    cmp r10, magic_segment_arr + 20
    je _set_magic_segment_flag
    jmp _end_of_update_magic_segment_status

    _set_magic_segment_flag:
    mov r14, 1

    _end_of_update_magic_segment_status:
    ; Number takes 4 bytes
    sub r8, 4 ; It's guaranteed (checked earlier) that read chunk from file is of size 4 * k
    cmp r8, 0
    jne _parse_loop

    ret


; Every read portion must satisfy: length mod 4 = 0
_check_portion_length:
    mov rax, r8
    and rax, 3 ; Modulo 4 ~ trick with binary mask, higher digits are not of interest to us.
    jnz _exit_with_one
    ret

_exit_with_one:
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall

_exit_procedure:
    cmp r15, 1
    jnz _set_equal_one
    cmp r14, 1
    jne _set_equal_one
    cmp r12d, MAGIC_CONST
    jne _set_equal_one

    mov rdi, 0
    jmp _exit_program

    _set_equal_one:
    mov rdi, 1

    _exit_program:
    mov rax, SYS_EXIT
    syscall
