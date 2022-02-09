BITS 32 

; ====================================================================
; 
; s(mall)ito
; 32 bit implementation of mito
; optimised for size by forging a custom elf header
; no padding, 360 bytes on my system ($ nasm sito32.asm)
; does not need to be memory mapped 
; knows all its own addressees
; can copy itself directly by measuring its own size
; uses recursion to scan the directories
; still not the fastest, but least syscalls  
; 
; ====================================================================

;--------- CONSTANTS ---------; 

; file syscall numbers
SYS_WRITE   equ 0x4         
SYS_CLOSE   equ 0x6         
SYS_EXIT    equ 0x3c        
SYS_OPEN    equ 0x5         

SYS_GETDENTS equ 0x8d
SYS_CHDIR    equ 0xc
SYS_MMAP     equ 0x9
SYS_ACCESS   equ 0x21

; open macros
O_RDONLY    equ 0x0
O_WRONLY    equ 0x1
O_CREAT     equ 0x40
O_DIRECTORY equ 0x10000
DT_DIR      equ 0x4
BUFSIZ      equ 0x200
;--------- CONSTANTS ---------; 

filstrt:
org 0x08048000

ehdr:                    ; Elf32_Ehdr
db 0x7F, "ELF", 1, 1, 1  ; e_ident
times 9 db 0
dw 2                     ; e_type
dw 3                     ; e_machine
dd 1                     ; e_version
dd _start                ; e_entry
dd phdr - $$             ; e_phoff
dd 0                     ; e_shoff
dd 0                     ; e_flags
dw ehdrsz                ; e_ehsize
dw phdrsz                ; e_phentsize
dw 1                     ; e_phnum
dw 0                     ; e_shentsize
dw 0                     ; e_shnum
dw 0                     ; e_shstrndx
ehdrsz equ $-ehdr

phdr:                    ; Elf32_Phdr
dd 1                     ; p_type
dd 0                     ; p_offset
dd $$                    ; p_vaddr
dd $$                    ; p_paddr
dd filesz                ; p_filesz
dd filesz                ; p_memsz
dd 5                     ; p_flags
dd 0x1000                ; p_align
phdrsz equ $-phdr

; code
section .text

; arg1 = ebx 
; arg2 = ecx
; arg3 = edx
; arg4 = esi 
; arg5 = ebp 

;; int _start(int argc, char **argv) {
_start:
       mov ebp, esp
       mov ebx, [esp+4]
       dec ebx 
       mov byte [ebx], '.' 

;;     int eax = recursive(".{argv[0]}")
       call recursive

;;     return eax
       mov ebx, eax
       jmp start_exit

start_bexit:
       xor ebx, ebx 
       inc bl 

start_exit:
       xor eax, eax 
       inc al
       int 0x80
;; }

;; int recursive(char *path) {
recursive:
;;     size_t bytes
;;     char d_type
;;     uint8_t esp[BUFSIZ]
;;     unsigned short d_reclen 
;;     int fd 
aloc     equ 0x20
d_type   equ 0xf
d_reclen equ 0x8
path     equ aloc 
bytes    equ aloc-0x4
type     equ aloc-0x8
reclen   equ aloc-0x9
fd       equ aloc-0xb

       pushad

       push ebp
       mov ebp, esp
       sub esp, aloc 
       mov [ebp-path], ebx ; arg1
       sub esp, BUFSIZ

;;     int eax = open(".", O_DIRECTORY)
;;     if (eax < 0) return 1
       xor eax, eax
       push '.'
       mov ebx, esp
       mov ecx, O_DIRECTORY
       mov al, SYS_OPEN
       int 0x80
       cmp eax, 0
       jle bexit
       mov ebx, eax


;;     bytes = getdents(eax, (struct linux_dirent *)rsp, BUFSIZ)
;;     if (bytes < 0 || bytes > BUFSIZ) return 1
       xor eax, eax
       mov ecx, esp
       mov edx, BUFSIZ
       mov al, SYS_GETDENTS
       int 0x80
       cmp eax, 0
       jl bexit
       cmp eax, BUFSIZ
       jg bexit
       mov [ebp-bytes], dword eax

;;     close(eax)
       xor eax, eax
       mov al, SYS_CLOSE
       int 0x80

;;     while(1) {
dirloop:
;;         char *ebx = esp.d_name
           mov ebx, esp
           xor eax, eax 

;;         type = esp.d_type
           mov al, byte [esp+d_type]
           mov [ebp-type], al

;;         reclen = esp.d_reclen
           mov ax, word [esp+d_reclen]
           mov word [ebp-reclen], ax

;;         esp += reclen                 // (next dirent)
           add esp, eax 

;;         if (bytes =< 0) break
           mov ecx, dword [ebp-bytes]
           test ecx, ecx 
           jle gexit

;;         bytes -= reclen           
           sub dword [ebp-bytes], eax

;;         if (type != DT_DIR) 
;;            continue 
           cmp byte [ebp-type], byte DT_DIR  
              jne dirloop 

;;         if (ebx[0] == '.')
           add ebx, 0xa
           cmp byte [ebx], '.'
           jne copy 
;;             if (ebx[1] == 0 || ebx[1] == '.')
;;                 continue
               cmp byte [ebx+1], '.'
                  je dirloop 
               cmp byte [ebx+1], 0x0 
                  je dirloop
    
copy:
;;         chdir(rdi)
           xor eax, eax
           mov al, SYS_CHDIR
           int 0x80
           cmp eax, 0
           jl bexit

;;         if (access(path, F_OK) != 0) {
           mov ebx, dword [ebp-path] 
           add ebx, 3
           xor ecx, ecx
           xor eax, eax
           mov al, SYS_ACCESS
           int 0x80 
           test eax, eax
           je copy_done 
                     
;;             fd = open(path+3, O_CREAT | O_WRONLY, 0777)
               mov ecx, O_CREAT ^ O_WRONLY
               mov edx, 0x1ff          ; 0777, umask
               xor eax, eax
               mov al, SYS_OPEN
               int 0x80
               cmp eax, 0
               jle bexit
               mov [ebp-fd], dword eax

;;             write(fd, filstrt, filesz)
               mov ebx, [ebp-fd]
               mov ecx, filstrt
               mov edx, filesz
write_loop:
               xor eax, eax
               mov al, SYS_WRITE
               int 0x80
               sub edx, eax
               add ecx, eax
               test edx, edx
               jg write_loop

;;             close(fd)
               mov ebx, dword [ebp-fd]
               xor eax, eax
               mov al, SYS_CLOSE
               int 0x80
copy_done:
;;         }
;;         recursive(path)
           mov ebx, dword [ebp-path]
           call recursive

;;         chdir("..")
           push '..'
           mov ebx, esp
           xor eax, eax
           mov eax, SYS_CHDIR
           int 0x80
           pop ebx 
           jmp dirloop
;;     }
;;     return 0
;; }
gexit:
       xor eax, eax
       jmp exit

bexit:
       xor eax, eax 
       inc eax

exit:
       mov esp, ebp
       pop ebp
       popad
       ret

filesz equ $-$$
