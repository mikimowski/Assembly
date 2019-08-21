; r15 - stores address of next char to read in given string == next operation to do
; r14 - stores euron ID
; r13 - used to store rsp address - before stack alignment

global euron

END_OF_STRING equ 0

extern get_value
extern put_value

section .bss
; First N indices are for euron 0, to communicate with consecutive eurons,
; Second N indices are for euron 1, to communicate with consecutive eurons,
; etc...
;
; synchro_value(i, j) - value for i from j
; Therefore value send from i to j will be placed under index = euron_id(j) * N + euron_id(i) = j * N + i
; And value send from j to i will be placed under index = i * N + j
align 16
synchro_value resq N * N
synchro_access resb N * N

section .text
align 16

euron:
    push rbp
    push r15
    push r14
    push r13
    mov rbp, rsp        ; rebase the stack

    mov r15, rsi
    mov r14, rdi

    parse_string:
    xor rax, rax
    mov al, byte [r15]
    cmp al, END_OF_STRING
    je exit

    binsearch_next_instruction:
    cmp al, '9'
    jle special_or_numeric
    ; Set of instructions sorted by ASCII code: B, C, D, E, G, P, S, n
    cmp al, 'E'
    jg GPSn
    je E
    cmp al, 'C'
    jg D
    je C

    B:  ; Branch - Pop value from the stack, if current value at the top of the stack is not 0 then
        ;   use popped value and move by given number of operations
    pop r8
    cmp qword [rsp], 0
    je end_of_binsearch_next_instruction
    add r15, r8
    jmp end_of_binsearch_next_instruction

    C:  ; Clean - pop value from the stack
    pop r8
    jmp end_of_binsearch_next_instruction

    D:  ; Duplicate - duplicate value on the top of the stack
    pop r8
    push r8
    push r8
    jmp end_of_binsearch_next_instruction

    E:  ; Exchange - exchange two values on the top of the stack
    pop r8
    pop r9
    push r8
    push r9
    jmp end_of_binsearch_next_instruction

    GPSn:
    cmp al, 'P'
    jg Sn
    je P

    G:  ; Get - push on the stack value returned by function: get_value(uint64_t euronID)
    mov rdi, r14
    xor rax, rax
    mov r13, rsp
    and rsp, -16        ; stack alignment
    call get_value
    mov rsp, r13
    push rax
    jmp end_of_binsearch_next_instruction

    P:  ; Put - pop value from the top of the stack and call function: put_value(uint64_t euronID, uint64_t value)
    pop rsi
    mov rdi, r14
    mov r13, rsp
    and rsp, -16        ; stack alignment
    call put_value
    mov rsp, r13
    jmp end_of_binsearch_next_instruction

    Sn:
    cmp al, 'S'
    jg n

    S:  ; Synchronize two eurons and exchange values from the top of their stacks
    call synchronize
    jmp end_of_binsearch_next_instruction

    n:  ; push euron's ID on the stack
    push r14
    jmp end_of_binsearch_next_instruction

    ; *, +, - 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
    special_or_numeric:
    cmp al, '0'
    jge numeric
    ; *, +, -
    cmp al, '+'
    jg minus
    ; *, +
    je plus

    asterisk:   ; Pop two values from the top of the stack, multiply them and push result on the stack
    pop r8
    pop r9
    imul r8, r9
    push r8
    jmp end_of_binsearch_next_instruction

    minus:      ; Pop one value from the top of the stack, negate it and push new value on the stack
    pop r8
    neg r8
    push r8
    jmp end_of_binsearch_next_instruction

    plus:       ; Pop two values from the top of the stack, add them and push result on the stack
    pop r8
    pop r9
    add r8, r9
    push r8
    jmp end_of_binsearch_next_instruction

    numeric:        ; Push value on top of the stack
    sub al, '0'     ; convert: ASCII -> number
    push rax        ; 64bits goes to the stack

    end_of_binsearch_next_instruction:
    add r15, 1
    jmp parse_string

    exit:
    pop rax         ; Value returned by function = current value from the top of the stack
    mov rsp, rbp    ; Restoring callee-saved registers
    pop r13
    pop r14
    pop r15
    pop rbp
    ret


; Function is explained from the perspective of i-th euron, that wants to communicate with j-th euron
synchronize:
    pop r10     ; Save address for return from function
    pop r9      ; Synchronize with euron which ID = r9
    pop r8      ; Send to it value from r8

    ; Step 1. Put your value, so that other euron can read it
    ; Send value under j * N + i index
    mov r11, r9
    imul r11, N
    add r11, r14
    wait_for_space:                         ; Perhaps previous value hasn't been read yet - iff synchro_access(j, i) == 1
    cmp byte [synchro_access + r11], 1      ; synchro_access(j, i) == 0 iff previous value was read ~ new value can be put
    je wait_for_space                       ; Wait for other euron to read previous value

    mov qword [synchro_value + r11 * 8], r8 ; Put the value
    mov byte [synchro_access + r11], 1      ; Tell other euron that you've put the value

    ; Step 2. Read value, sent for you
    ; Read value from i * N + j index
    mov r11, r14
    imul r11, N
    add r11, r9
    wait_for_value:
    cmp byte [synchro_access + r11], 0      ; synchr_accesso(i, j) == 1 iff value is available to read (value for i from j)
    je wait_for_value                       ; Wait for other euron to put the value for you

    mov r8, qword [synchro_value + r11 * 8] ; Save received value
    mov byte [synchro_access + r11], 0      ; Tell other euron that you've read the value

    push r8                                 ; Save read value
    push r10                                ; Restore function return address
    ret
