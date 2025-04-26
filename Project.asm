[org 0x0100]
jmp start

; Snake structure (3 segments)
segment_rows: db 10, 10, 10  ; Initial positions
segment_cols: db 10, 9, 8    ; Horizontal line
direction: db 3              ; Start moving right (3
new_direction: db 3

clrscr:
    push es
    push ax
    push di
    mov ax, 0xb800
    mov es, ax
    xor di, di
nextloc:
    mov word [es:di], 0x0720
    add di, 2
    cmp di, 4000
    jne nextloc
    pop di
    pop ax
    pop es
    ret

delay:
    push cx
    push dx
    mov cx, 0x000F
delay_loop:
    mov dx, 0x0ffF
delay_inner:
    dec dx
    jnz delay_inner
    dec cx
    jnz delay_loop
    pop dx
    pop cx
    ret

draw_snake:
    pusha
    mov ax, 0xb800
    mov es, ax
    mov cx, 3              ; Total segments
    mov si, 0

draw_segment:
    ; Calculate position for current segment
    mov al, [segment_rows + si]
    mov bl, 80
    mul bl
    add al, [segment_cols + si]
    adc ah, 0              ; Handle carry
    shl ax, 1
    mov di, ax
    
    ; Draw segment
    mov word [es:di], 0x0723  ; '#'
    inc si
    loop draw_segment
    popa
    ret

update_positions:
    ; Save old head position
    mov al, [segment_rows]
    mov bl, [segment_cols]

    ; Shift body positions
    mov cx, 2
shift_loop:
    mov si, cx
    mov al, [segment_rows + si - 1]
    mov [segment_rows + si], al
    mov al, [segment_cols + si - 1]
    mov [segment_cols + si], al
    dec cx
    jnz shift_loop

    ; Update head based on direction
    cmp byte [direction], 0
    je move_up
    cmp byte [direction], 1
    je move_down
    cmp byte [direction], 2
    je move_left
    cmp byte [direction], 3
    je move_right

move_up:
    dec byte [segment_rows]
    ret
move_down:
    inc byte [segment_rows]
    ret
move_left:
    dec byte [segment_cols]
    ret
move_right:
    inc byte [segment_cols]
    ret

start:
    call clrscr

game_loop:
    call delay
    
    ; Check for key press
    mov ah, 01h
    int 16h
    jz no_key
    mov ah, 00h
    int 16h
    cmp ah, 72
    je change_up
    cmp ah, 80
    je change_down
    cmp ah, 4Bh
    je change_left
    cmp ah, 4Dh
    je change_right
    jmp no_key

change_up:
    cmp byte [direction], 1  ; Prevent 180° turn
    je no_key
    mov byte [new_direction], 0
    jmp no_key
change_down:
    cmp byte [direction], 0
    je no_key
    mov byte [new_direction], 1
    jmp no_key
change_left:
    cmp byte [direction], 3
    je no_key
    mov byte [new_direction], 2
    jmp no_key
change_right:
    cmp byte [direction], 2
    je no_key
    mov byte [new_direction], 3

no_key:
    ; Update direction at end of frame
    mov al, [new_direction]
    mov [direction], al

    call clrscr
    call update_positions
    call draw_snake
    jmp game_loop
