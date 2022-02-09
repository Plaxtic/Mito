BITS 64

; ====================================================================
;
; f(ast)ito
; same as eito but copies itself recursively to all higher directories
; lighter on RAM because no forking/execution
; slower/less cool as an isolated process, but faster at completing its task
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
BUFSIZ      equ 0x200
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
;;     unsigned long  d_ino      /* Inode number */
;;     unsigned long  d_off      /* Offset to next linux_dirent */
;;     unsigned short d_reclen   /* Length of this linux_dirent */
;;     char           d_name[]   /* Filename (null-terminated) */
;;                       /* length is actually (d_reclen - 2 -
;;                          offsetof(struct linux_dirent, d_name)) */

;;     char           pad        // Zero padding byte
;;     char           d_type     // File type (only since Linux
;;                               // 2.6.4); offset is (d_reclen + 1)

;; }


;; int _start(int argc, char **argv) {
_start:
;;     char *r8 = ".{argv[0]}" e.g. "../aito"
       mov rbp, rsp
       mov r8, [rsp+8]
       dec r8
       mov byte [r8], '.' 

;;     int rax = recursive(r8)
       mov rdi, r8
       call recursive

;;     return rax
       mov rdi, rax
       xor rax, rax
       mov al, SYS_EXIT
       syscall
;; }

;; int recursive(char *rdi) {
recursive:
       push rdi
       push rsi
       push rdx
       push rcx
       push r8
       push r9
       push r11
       push r12
       push r13
       push r14
       push r15

       push rbp
       mov rbp, rsp
;;     char *r8 = rdi
       mov r8, rdi  

;;     int r9 = open(".", O_DIRECTORY)
;;     if (r9 < 0) return 1
       xor rax, rax
       push '.'
       mov rdi, rsp
       mov rsi, O_DIRECTORY
       mov al, SYS_OPEN
       syscall
       cmp rax, 0
       jle bexit
       mov r9, rax
;;     uint8_t *rsp[BUFSIZ]
       sub rsp, BUFSIZ
;;     int r12 = getdents(r9, (struct linux_dirent *)rsp, BUFSIZ)
;;     if (r12 < 0) return 1
       xor rax, rax
       mov rdi, r9
       mov rsi, rsp
       mov rdx, BUFSIZ
       mov al, SYS_GETDENTS64
       syscall
       cmp rax, 0
       jl bexit
       mov r12, rax

;;     close(r9)
       mov rdi, r9
       xor rax, rax
       mov al, SYS_CLOSE
       syscall

;;     while(r12 > 0) {
dirloop:
           test r12, r12
           jle gexit

           mov rdi, rsp
           xor r9, r9
           mov r15b, byte [rsp+0x12]
;;         unsigned short r9w = rsp.d_reclen
           mov r9w, word [rsp+0x10]   
;;         rsp += r_reclen (next dirent)
           add rsp, r9                
;;         r12 -= r_reclen
           sub r12, r9 
;;         char r9b = rsp.d_type  // (rsp-1)
           mov r9b, byte [rsp-1]    

;;         if (d_type != DT_DIR or name[0:2] = ".\0" or name[0:2] = "..") 
;;             continue
           cmp r15b, byte DT_DIR  
           jne dirloop 
           add rdi, 0x13
           cmp byte [rdi], '.'
           jne chdir
           cmp byte [rdi+1], '.'
           je dirloop 
           cmp byte [rdi+1], 0x0 
           je dirloop
    
chdir:
;;         chdir(rdi)
           xor rax, rax
           mov al, SYS_CHDIR
           syscall
           cmp rax, 0
           jl bexit

;;         r13 = open(rdi, O_RDONLY)
           mov rdi, r8
           xor rsi, rsi            ; O_RDONLY
           xor rax, rax
           mov al, SYS_OPEN
           syscall
           cmp rax, 0

           jle bexit
           mov r13, rax

;;         r14 = open(rdi+3, O_CREAT|O_WRONLY, 0777)
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
           mov rdi, r14
           mov rsi, r13
           xor rdx, rdx
cp:
           mov r10, 0x2000
           xor rax, rax
           mov al, SYS_SENDFILE
           syscall
           cmp rax, 0
           jl bexit
           jnz cp
;;         close(r13), close(r14)
           mov rdi, r14
           xor rax, rax
           mov al, SYS_CLOSE
           syscall
           mov rdi, r13
           xor rax, rax
           mov al, SYS_CLOSE
           syscall
;;         recursive(r8)
           mov rdi, r8
           call recursive
;;         chdir("..")
           push '..'
           mov rdi, rsp
           xor rax, rax
           mov rax, SYS_CHDIR
           syscall
           pop rdi
           jmp dirloop
;;     }

;;     return 0
;; }
gexit:
       xor rax, rax
       xor rdi, rdi
       jmp exit

bexit:
       xor rax, rax 
       inc rax

exit:
       leave
       pop r15
       pop r14
       pop r13
       pop r12
       pop r11
       pop r9
       pop r8
       pop rcx
       pop rdx
       pop rsi
       pop rdi

       ret

