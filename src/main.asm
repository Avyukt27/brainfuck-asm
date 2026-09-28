DEFAULT REL

%define SYS_READ 0
%define SYS_WRITE 1
%define SYS_OPEN 2
%define SYS_EXIT 60

%define FD_STDOUT 1

%define O_RDONLY 0

section .data
  filename db "main.bf", 0

section .bss
  buf: resb 8

section .text
  global _start

_start:
  mov rax, SYS_OPEN
  lea rdi, [filename]
  mov rsi, O_RDONLY
  syscall
  cmp rax, 0
  jl exit_with_code

  ; rax has the file descriptor
  mov rdi, rax
  mov rax, SYS_READ
  lea rsi, [buf]
  mov rdx, 8
  syscall
  cmp rax, 0
  jl exit_with_code

  ; buf contains the read data
  mov rax, SYS_WRITE
  mov rdi, FD_STDOUT
  lea rsi, [buf]
  mov rdx, 8
  syscall

  mov rax, SYS_EXIT
  xor rdi, rdi
  syscall

; exit_with_code
; Args:
;   rdi: Return code
exit_with_code:
  mov rax, SYS_EXIT
  syscall
