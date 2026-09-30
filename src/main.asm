DEFAULT REL

%define SYS_READ 0
%define SYS_WRITE 1
%define SYS_OPEN 2
%define SYS_CLOSE 3
%define SYS_LSEEK 8
%define SYS_EXIT 60

%define FD_STDIN 0
%define FD_STDOUT 1
%define FD_STDERR 2

%define O_RDONLY 0

section .rodata
  OPEN_ERR db "Error in opening file", 10, 0
  OPEN_ERR_LEN equ $ - OPEN_ERR
  READ_ERR db "Error in reading file", 10, 0
  READ_ERR_LEN equ $ - READ_ERR
  INT_ERR db "Error in program execution", 10, 0
  INT_ERR_LEN equ $ - INT_ERR

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
  buf resb 1
  loop_start_idxs resq 255

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
  xor r13, r13 ; current loop depth

  ; read 1 byte (char) of file
byte_read:
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

do_inc:
  inc byte [data + r12]
  jmp byte_read
do_dec:
  dec byte [data + r12]
  jmp byte_read
do_next:
  inc r12
  jmp byte_read
do_prev:
  dec r12
  jmp byte_read
do_output:
  mov rax, SYS_WRITE
  mov rdi, FD_STDOUT
  lea rsi, [data + r12]
  mov rdx, 1
  syscall
  jmp byte_read
do_input:
  mov rax, SYS_READ
  mov rdi, FD_STDIN
  lea rsi, [data + r12]
  mov rdx, 1
  syscall
  jmp byte_read
do_loop_start:
do_loop_end:
skip_char:
  jmp byte_read
