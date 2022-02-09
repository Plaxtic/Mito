BITS 64

; ====================================================================
;
; z(ippy)ito
; same as fito only the file is memory mapped
; faster and far less syscalls
; slightly more memory used because of the mapping
; 
; ====================================================================

;--------- CONSTANTS ---------; 

; file syscalls
SYS_READ     equ 0x0         
SYS_WRITE    equ 0x1         
SYS_OPEN     equ 0x2         
SYS_CLOSE    equ 0x3         
SYS_STAT     equ 0x4
SYS_MMAP     equ 0x9
SYS_SENDFILE equ 0x28

; dir syscalls
SYS_GETDENTS64 equ 0xd9
SYS_CHDIR      equ 0x50

; IPC syscalls
SYS_WAIT4  equ 0x3d
SYS_FORK   equ 0x39
SYS_EXECVE equ 0x3b
SYS_EXIT   equ 0x3c        

; open macros
O_RDONLY    equ 0x0
O_WRONLY    equ 0x1
O_CREAT     equ 0x40
O_DIRECTORY equ 0x10000
DT_DIR      equ 0x4

; mycros
BUFSIZ           equ 0x200
SIZEOFSTRUCTSTAT equ 0x74
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

;; int main(int argc, char **argv) {
_start:
    ;;     r13 = "." + argv[0]
    mov rbp, rsp
    mov r13, [rsp+8]
    dec r13
    mov byte [r13], '.' 

    ;;     int r14 = open(argv[0], O_RDONLY)
    ;;     if (r14 < 0) return 1
    mov rdi, r13
    inc rdi
    xor rsi, rsi
    xor rax, rax
    mov al, SYS_OPEN
    syscall
    test rax, rax
    jl start_bexit
    mov r14, rax

    ;;     struct stat rsp
    sub rsp, SIZEOFSTRUCTSTAT+10

    ;;     if (stat(argv[0], &rsp) != 0) return 1
    mov rsi, rsp
    xor rax, rax
    mov al, SYS_STAT
    syscall
    test rax, rax
    jnz start_bexit

;;     size_t r12 = rsp.st_size
    mov r12, [rsp+0x30] 
    add rsp, SIZEOFSTRUCTSTAT+10

    ;;     uint8_t *r15 = mmap(NULL, r12, PROT_READ, MAP_SHARED, r14, 0)
    ;;     if (r15 == MAP_FAILED) return 1
    xor rdi, rdi
    mov rsi, r12 
    xor rdx, rdx
    inc rdx           ; PROT_READ
    xor r10, r10 
    inc r10           ; MAP_SHARED
    mov r8, r14 
    xor r9, r9
    xor rax, rax
    mov al, SYS_MMAP
    syscall
    cmp rax, -1       ; MAP_FAILED
    je start_bexit 
    mov r15, rax

    ;;     close(r14)
    mov rdi, r14
    xor rax, rax
    mov al, SYS_CLOSE
    syscall

    ;;     int rax = recursive(r13, r14, r12)
    mov rdi, r13 
    mov rsi, r15
    mov rdx, r12
    call recursive

    ;;     return rax
    mov rdi, rax
    jmp start_exit

start_bexit:
    xor rdi, rdi
    inc rdi

start_exit:
    xor rax, rax
    mov al, SYS_EXIT
    syscall
;;}

    ;; int recursive(char *rdi, uint8_t *rsi, size_t rdx)
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
;;     uint8_t *r13 = rsi
       mov r13, rsi
;;     size_t r15  = rdx
       mov r15, rdx

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

;;     while(1) {
dirloop:
           mov rdi, rsp
           xor r9, r9
           mov r15b, byte [rsp+0x12]
;;         unsigned short r9w = rsp.d_reclen
           mov r9w, word [rsp+0x10]   
;;         rsp += r_reclen (next dirent)
           add rsp, r9                
           sub r12, r9
;;         if (r12 =< 0) break
           test r12, r12
           jle gexit
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

;;         rax = open(rdi+3, O_RDONLY)
;;         if (rax < 0) { 
           mov rdi, r8
           add rdi, 3
           xor rsi, rsi
           xor rax, rax
           mov al, SYS_OPEN
           syscall
           test rax, rax 
           jg write_done
                      
;;             r14 = open(rdi+3, O_CREAT|O_WRONLY, 0777)
               mov rsi, O_CREAT ^ O_WRONLY
               mov rdx, 0x1ff          ; 0777, umask
               xor rax, rax
               mov al, SYS_OPEN
               syscall
               cmp rax, 0
               jle bexit
               mov r14, rax

;;             while ((rax = write(r14, r13, r15)) < r15)  // do stuff
               mov rdi, r14
               mov rsi, r13
               mov rdx, r15
rep_write:
               xor rax, rax
               inc al
               syscall
               cmp rax, rdx
               jge write_done
               add rsi, rax
               sub rdx, rax
               jmp rep_write

write_done:
;;         }
;;         close(r14)
           mov rdi, r14
           xor rax, rax
           mov al, SYS_CLOSE
           syscall

;;         recursive(r8, r13, r15)
           mov rdi, r8
           mov rsi, r13
           mov rdx, r15
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

