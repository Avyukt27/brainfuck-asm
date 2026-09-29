DEFAULT REL

%define SYS_READ 0
%define SYS_WRITE 1
%define SYS_OPEN 2
%define SYS_EXIT 60

%define FD_STDOUT 1
%define FD_STDERR 2

%define O_RDONLY 0

section .rodata
  OPEN_ERR db "Error in opening file", 10, 0
  OPEN_ERR_LEN equ $ - OPEN_ERR
  READ_ERR db "Error in reading file", 10, 0
  READ_ERR_LEN equ $ - READ_ERR

  filename db "main.bf", 0

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
  data times 255 db 0 ; data array

section .bss
  buf: resb 8

section .text
  global _start

_start:
  ; open file "main.bf" and retrieve file descriptor
  mov rax, SYS_OPEN
  lea rdi, [filename]
  mov rsi, O_RDONLY
  syscall

  ; exit on error
  cmp rax, 0
  jl open_failed

  ; move file descriptor to r15
  mov r15, rax

  xor r12, r12 ; data pointer

  ; read 8 byte (char) chunks of file
chunk_read:
  ; r15 has the file descriptor
  mov rax, SYS_READ
  mov rdi, r15
  lea rsi, [buf]
  mov rdx, 8
  syscall

  ; exit on error
  test rax, rax
  jl read_failed
  ; exit on EOF
  jz exit

  mov r14, rax ; store no. of bytes read in r14
  xor r13, r13 ; index counter in input byte

process_chunk:
  movzx rbx, byte [buf + r13]
  jmp [jump_table + rbx * 8]

next_chunk:
  inc r13
  cmp r13, r14
  jl process_chunk
  jmp chunk_read

exit:
  ; exit with code 0
  mov rax, SYS_EXIT
  xor rdi, rdi
  syscall

open_failed:
  neg rax ; turn negative error into a positive exit code
  mov rdi, rax
  lea rsi, [OPEN_ERR]
  mov rdx, OPEN_ERR_LEN
  jmp err_exit

read_failed:
  neg rax
  mov rdi, rax
  lea rsi, [READ_ERR]
  mov rdx, READ_ERR_LEN
  jmp err_exit

; err_exit
; Exits the program with an error code and message
; Args:
;   rdi: Return code
;   rsi: Pointer to error message
;   rdx: Length of error message
err_exit:
  mov r8, rdi ; store return code in r8

  mov rax, SYS_WRITE
  mov rdi, FD_STDERR
  syscall

  ; exit with exit code
  mov rax, SYS_EXIT
  mov rdi, r8
  syscall

do_inc:
  inc byte [data + r12]
  jmp next_chunk
do_dec:
  dec byte [data + r12]
  jmp next_chunk
do_next:
  inc r12
  jmp next_chunk
do_prev:
  dec r12
  jmp next_chunk
do_output:
  mov rax, SYS_WRITE
  mov rdi, FD_STDOUT
  lea rsi, [data + r12]
  mov rdx, 1
  syscall
  jmp next_chunk
do_input:
do_loop_start:
do_loop_end:
skip_char:
  jmp next_chunk

next_instruction:
  inc r13
  cmp r13, r14
  jl process_chunk
  jmp chunk_read
