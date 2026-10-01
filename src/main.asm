DEFAULT REL

SYS_READ equ 0
SYS_WRITE equ 1
SYS_OPEN equ 2
SYS_CLOSE equ 3
SYS_LSEEK equ 8
SYS_EXIT equ 60

FD_STDIN equ 0
FD_STDOUT equ 1
FD_STDERR equ 2

O_RDONLY equ 0

SEEK_START equ 0
SEEK_CUR equ 1

DATA_SIZE equ 65536 ; 2^16 cells in tape

section .rodata
  OPEN_ERR db "Error in opening file", 10, 0
  OPEN_ERR_LEN equ $ - OPEN_ERR
  READ_ERR db "Error in reading file", 10, 0
  READ_ERR_LEN equ $ - READ_ERR
  INT_ERR db "Error in program execution", 10, 0
  INT_ERR_LEN equ $ - INT_ERR
  MISSING_ARG_ERR db "Did not receive enough arguments", 10, 0
  MISSING_ARG_ERR_LEN equ $ - MISSING_ARG_ERR

  jump_table:
    %assign i 0
    %rep 256
        %if i == '+'
            dq do_inc
        %elif i == '-'
            dq do_dec
        %elif i == '>'
            dq do_next
        %elif i == '<'
            dq do_prev
        %elif i == '.'
            dq do_output
        %elif i == ','
            dq do_input
        %elif i == '['
            dq do_loop_start
        %elif i == ']'
            dq do_loop_end
        %else
            dq skip_char
        %endif
        %assign i i+1
    %endrep


section .data
  data times DATA_SIZE db 0 ; data array

section .bss
  buf resb 1
  loop_start_idxs resq 255

section .text
  global _start

_start:
  ; [rsp] has argc, it should be 2
  mov rcx, [rsp]
  cmp rcx, 2
  jl  missing_argument_err ; error if less than 2 arguments were provided
  ; [rsp + 16] has argv[1] (the pointer to the filename)
  mov rdi, [rsp + 16] ; rdi has pointer to filename

  ; open file and retrieve file descriptor
  mov rax, SYS_OPEN
  mov rsi, O_RDONLY
  syscall

  ; exit on error
  cmp rax, 0
  jl open_failed

  ; move file descriptor to r15
  mov r15, rax

  xor r12, r12 ; data pointer
  xor r13, r13 ; current loop depth

  ; read 1 byte (char) of file
read_byte:
  ; r15 has the file descriptor
  mov rax, SYS_READ
  mov rdi, r15
  lea rsi, [buf]
  mov rdx, 1
  syscall

  ; exit on error
  test rax, rax
  jl read_failed
  ; exit on EOF
  jz exit

  movzx rbx, byte [buf] ; read byte form buf into rbx
  jmp [jump_table + rbx * 8] ; jump to corresponding routine

exit:
  ; close file fd
  mov rax, SYS_CLOSE
  mov rdi, r15
  syscall

  ; exit with code 0
  mov rax, SYS_EXIT
  xor rdi, rdi
  syscall

open_failed:
  neg rax ; turn negative error into a positive exit code
  mov r8, rax ; store exit code in r8

  ; write error message
  mov rax, SYS_WRITE
  mov rdi, FD_STDERR
  lea rsi, [OPEN_ERR]
  mov rdx, OPEN_ERR_LEN
  syscall

  ; exit with exit code
  mov rax, SYS_EXIT
  mov rdi, r8
  syscall

read_failed:
  neg rax ; turn negative error into a positive exit code
  mov r8, rax ; store exit code in r8

  ; write error message
  mov rax, SYS_WRITE
  mov rdi, FD_STDERR
  lea rsi, [READ_ERR]
  mov rdx, READ_ERR_LEN
  syscall

  ; close file fd
  mov rax, SYS_CLOSE
  mov rdi, r15
  syscall

  ; exit with exit code
  mov rax, SYS_EXIT
  mov rdi, r8
  syscall

interpreter_err:
  ; write error message
  mov rax, SYS_WRITE
  mov rdi, FD_STDERR
  lea rsi, [INT_ERR]
  mov rdx, INT_ERR_LEN
  syscall

  ; close file fd
  mov rax, SYS_CLOSE
  mov rdi, r15
  syscall

  ; exit with exit code
  mov rax, SYS_EXIT
  mov rdi, 1
  syscall

missing_argument_err:
  ; write error message
  mov rax, SYS_WRITE
  mov rdi, FD_STDERR
  lea rsi, [MISSING_ARG_ERR]
  mov rdx, MISSING_ARG_ERR_LEN
  syscall

  ; exit with exit code
  mov rax, SYS_EXIT
  mov rdi, 1
  syscall

do_inc:
  inc byte [data + r12]
  jmp read_byte
do_dec:
  dec byte [data + r12]
  jmp read_byte
do_next:
  inc r12
  and r12, DATA_SIZE - 1
  jmp read_byte
do_prev:
  dec r12
  and r12, DATA_SIZE - 1
  jmp read_byte
do_output:
  mov rax, SYS_WRITE
  mov rdi, FD_STDOUT
  lea rsi, [data + r12]
  mov rdx, 1
  syscall
  jmp read_byte
do_input:
  mov rax, SYS_READ
  mov rdi, FD_STDIN
  lea rsi, [data + r12]
  mov rdx, 1
  syscall
  jmp read_byte
do_loop_start:
  cmp byte [data + r12], 0
  je .skip_loop_body ; if current cell is 0, skip to end of loop

  ; save the address after [ as loop start point
  mov rax, SYS_LSEEK
  mov rdi, r15 ; file fd
  xor rsi, rsi ; offset 0
  mov rdx, SEEK_CUR ; get current position
  syscall

  mov qword [loop_start_idxs + r13 * 8], rax ; push onto loop stack
  inc r13 ; increase depth
  jmp read_byte
.skip_loop_body:
  mov r14, 1 ; r14 will track local bracket nesting depth for this skip
.scan_forward:
  ; read byte from the file stream into a byte on stack
  push qword 0 ; allocate space on stack for 1 character
  mov rax, SYS_READ
  mov rdi, r15
  mov rsi, rsp ; buffer is the stack pointer
  mov rdx, 1
  syscall
  
  cmp rax, 0 ; EOF reached without finding matching ]
  jle interpreter_err 

  pop rax ; al now contains the character read
  
  cmp al, '[' ; nested open loop
  je .nest_open
  cmp al, ']'  ; loop end
  je .nest_close
  jmp .scan_forward
.nest_open:
  inc r14
  jmp .scan_forward
.nest_close:
  dec r14
  cmp r14, 0
  jg .scan_forward ; if r14 > 0, we are inside nested loops
  
  ; loop is FINALLY over
  jmp read_byte

do_loop_end:
  cmp byte [data + r12], 0
  je .exit_loop ; if current cell is 0, end loop

  ; jump back to the instruction AFTER the [
  cmp r13, 0
  jle interpreter_err ; not in a loop check

  mov rax, SYS_LSEEK
  mov rdi, r15
  mov rsi, qword [loop_start_idxs + (r13 - 1) * 8] ; Peek at the top item without changing r13 yet
  mov rdx, SEEK_START
  syscall

  jmp read_byte

.exit_loop:
  ; pop loop start location from stack because this loop is done
  cmp r13, 0
  jle interpreter_err
  dec r13 ; Safely discard the index from the tracking stack
  jmp read_byte
skip_char:
  jmp read_byte
