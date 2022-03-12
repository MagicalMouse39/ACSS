; Created by Magical
;
; Compile this program with:
; nasm -f elf64 -o server.o server.asm
;
; Link the ELF with:
; ld -o server server.o
;
; Run the program with:
; ./server

BITS 64

; Declare sockaddr_in struct template
struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .rodata
    newline db 13, 10
    newline_len equ $ - newline

    backlog db 32

section .data
    server_addr istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2
        at sockaddr_in.sin_port,   dw 55335
        at sockaddr_in.sin_addr,   dd 0
        at sockaddr_in.sin_zero,   dq 0
    iend
    server_addr_len equ $ - server_addr

    msg db 'Prova'
    msg_len equ $ - msg

section .bss
    client_addr istruc sockaddr_in
        at sockaddr_in.sin_family, resw 1
        at sockaddr_in.sin_port, resw 1
        at sockaddr_in.sin_addr, resd 1
        at sockaddr_in.sin_zero, resb 8
    iend
    client_addr_len equ $ - client_addr
    client_addr_len_p resq 1

    server_socket resq 1
    client_socket resq 1

    char_buf resb 1

    read_buf resb 1024
    read_buf_len equ $ - read_buf

    data_operator resb 1
    data_number_a resq 1
    data_number_b resq 1

section .text

; Print
; rsi: text
; rdx: text length
print:
    mov rax, 1
    mov rdi, 1
    syscall
    ret

; Perror
; rsi: text
; rdx: text length
perror:
    mov rax, 1
    mov rdi, 2
    syscall
    ret

; Close
; rdi: File descriptor
close:
    mov rax, 3
    syscall
    ret

; Read
; rdi: File descriptor
; rsi: buffer
; rdx: buffer_len
read:
    mov rax, 0
    syscall
    ret

; Read char
; rdi: File descriptor
; -> The character
read_char:
    push rsi
    push rdx

    mov rsi, char_buf
    mov rdx, QWORD 1
    call read

    mov al, BYTE [char_buf]
    
    pop rsi
    pop rdx
    ret

; Read til space
; rdi: File descriptor
; rsi: buffer
; rdx: character
; -> Number of read characters
read_to_char:
    push rsi
    push r8
    push r9
    push r10

    mov r10, rdx
    xor r9, r9
    mov r8, rsi

    .read_loop:
        call read_char
        mov [r8], BYTE al

        inc r8
        inc r9
        cmp rax, r10
        jne .read_loop

    dec r8
    mov [r8], BYTE 0

    dec r9
    mov rax, r9

    pop r10
    pop r9
    pop r8
    pop rsi
    ret

; Write
; rdi: File descriptor
; rsi: buffer
; rdx: buffer_len
write:
    mov rax, 1
    syscall
    ret

; Exit
exit:
    mov rax, 60
    mov rdi, 0
    syscall
    ret

; String to int
; rdi: buffer
; rsi: buffer_len
; -> The converted string
str_to_int:
    push rcx
    push r8
    xor r8, r8
    xor rcx, rcx

    cmp BYTE [rdi], 0x2d
    je .neg_number
    
    push 0x0
    jmp .convert_loop
    
    .neg_number:
        push 0x1

    .convert_loop:
        imul rcx, QWORD 0x0a
        mov bl, [rdi]
        sub bl, 0x30
        add cl, bl

        inc rdi
        inc r8
        cmp r8, rsi
        jl .convert_loop

    pop r8
    cmp r8, 0x0
    je .end

    mov r8, -0x1
    imul rcx, r8

    .end:
    mov rax, rcx
    pop r8
    pop rcx
    ret

; Int to string
; rdi: buffer
; rsi: integer
int_to_str:
    push rdx
    push r8
    push r9
    push rsi
    mov rcx, rsi
    xor rdx, rdx
    xor r9, r9

    .convert_loop:
        mov rax, rcx
        mov r8, 0x0a
        xor edx, edx
        idiv r8

        add dl, 0x30
        mov [rdi], dl
        inc rdi
        inc r9

        mov rcx, rax
        
        cmp rcx, 0x0
        jg .convert_loop

    mov [rdi], BYTE 0x0

    mov rax, r9

    pop rsi
    pop r9
    pop r8
    pop rdx
    ret

; Reverse String
; rdi: Buffer
; rsi: Buffer len
reverse_str:
    push rdx
    push rcx
    push r8
    push r9
    push r10

    xor rcx, rcx
    mov r8, rdi
    mov r9, rdi
    mov r10, rsi

    add r9, r10
    dec r9

    push rdx
    xor rdx, rdx
    mov rax, r10
    mov r10d, 2
    div r10d
    mov r10, rax
    pop rdx

    .reverse_loop:
        mov al, [r9]
        mov dl, [r8]
        mov [r9], BYTE dl
        mov [r8], BYTE al

        inc r8
        dec r9

        inc rcx
        cmp rcx, r10
        jl .reverse_loop

    pop r10
    pop r9
    pop r8
    pop rcx
    pop rdx
    ret


; Calculate
; rdi: Operator
; rsi: Number A
; rdx: Number B
calculate:
    cmp rdi, '+'
    je .add
    cmp rdi, '-'
    je .sub
    cmp rdi, '*'
    je .mul
    cmp rdi, '/'
    je .div

    xor rax, rax
    jmp .end
    
    .add:
        mov rax, rsi
        add rax, rdx
        jmp .end
    
    .sub:
        mov rax, rsi
        sub rax, rdx
        jmp .end
    .mul:
        mov rax, rsi
        imul rax, rdx
        jmp .end
    
    .div:
        mov rax, rsi
        push r8
        mov r8, rdx
        xor rdx, rdx
        idiv r8
        pop r8

    .end:
    ret

global _start
_start:
    ; Create socket
    mov rax, 41                 ; socket()
    mov rdi, 2                  ; AF_INET
    mov rsi, 1                  ; SOCK_STREAM
    xor rdx, rdx                ; Protocol (0)
    syscall
    mov [server_socket], rax    ; Sock's fd is now in server_socket

    ; Bind
    mov rax, 49                 ; bind()
    mov rdi, [server_socket]    ; socket fd
    mov rsi, server_addr        ; sockaddr_in
    mov rdx, server_addr_len    ; len(sockaddr_in)
    syscall

    ; Listen
    mov rax, 50                 ; listen()
    mov rdi, [server_socket]    ; socket fd
    mov rsi, [backlog]          ; Backlog
    syscall

    mov QWORD [client_addr_len_p], QWORD client_addr_len

    .accept_loop:
        push rcx

        ; Accept
        mov rax, 43                 ; accept()
        mov rdi, [server_socket]    ; socket fd
        mov rsi, client_addr        ; sockaddr_in
        mov rdx, client_addr_len_p  ; len(sockaddr_in)
        syscall
        mov [client_socket], rax

        ; Receive the operator
        mov rdi, [client_socket]
        mov rsi, read_buf
        mov rdx, 0x20
        call read_to_char

        ; Store the received operator (single char)
        xor rcx, rcx
        mov cl, [read_buf]
        mov [data_operator], cl

        ; Receive the first number
        mov rdi, [client_socket]
        mov rsi, read_buf
        mov rdx, 0x20
        call read_to_char

        ; Convert to int the received string
        mov rdi, read_buf
        mov rsi, rax
        call str_to_int

        ; Store the first number
        mov [data_number_a], rax

        ; Receive the second number
        mov rdi, [client_socket]
        mov rsi, read_buf
        mov rdx, 0x0a
        call read_to_char

        ; Convert to int the received string
        mov rdi, read_buf
        mov rsi, rax
        call str_to_int

        ; Store the received number
        mov [data_number_b], rax

        ; Print Number A
        mov rdi, read_buf
        mov rsi, [data_number_a]
        call int_to_str

        mov rdi, read_buf
        mov rsi, rax
        call reverse_str

        mov rsi, read_buf
        mov rdx, 100
        call print

        ; Print Operator
        mov rsi, data_operator
        mov rdx, 1
        call print

        ; Print Number B
        mov rdi, read_buf
        mov rsi, [data_number_b]
        call int_to_str

        mov rdi, read_buf
        mov rsi, rax
        call reverse_str

        mov rsi, read_buf
        mov rdx, 100
        call print

        ; Print New Line
        mov rsi, newline
        mov rdx, newline_len
        call print

        ; Calculate the result of the operation requested by the client
        xor rax, rax
        xor rsi, rsi
        xor rdx, rdx
        mov al, [data_operator]
        mov rdi, rax
        mov rsi, [data_number_a]
        mov rdx, [data_number_b]
        call calculate

        ; Convert the "calculate()" result to string
        mov rdi, read_buf
        mov rsi, rax
        call int_to_str

        ; Save the length of the string
        mov r11, rax

        ; Reverse the string to send
        mov rdi, read_buf
        mov rsi, r11
        call reverse_str

        ; Send the result back to the client
        mov rdi, [client_socket]
        mov rsi, read_buf
        mov rdx, r11
        call write

        ; Close the client socket
        mov rdi, [client_socket]
        call close

        ; Loop to accept another client
        pop rcx
        jmp .accept_loop

    mov rdi, [server_socket]
    call close

    call exit
