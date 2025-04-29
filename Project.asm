[org 0x0100]
jmp start

; Game data structure
segment_rows: db 10,10,10,0,0,0,0,0,0,0
segment_cols: db 10,9,8,0,0,0,0,0,0,0
snake_length: db 3
direction: db 3
new_direction: db 3
food_row: db 0
food_col: db 0
score: dw 0
game_over: db 0
paused: db 0
speed: dw 0xBFFF
last_second: db 0

; Data
score_label db 'Score: '
score_label_len equ $ - score_label

; Variables
last_tail_row: db 0
last_tail_col: db 0

; Constants
FOOD_CHAR equ '*'
FOOD_COLOR equ 0x0C
SNAKE_COLOR equ 0x07
BOUNDARY_COLOR equ 0x07
MAX_LENGTH equ 10
BOUNDARY_TOP equ 1
BOUNDARY_BOTTOM equ 23
BOUNDARY_LEFT equ 1
BOUNDARY_RIGHT equ 78

; Messages
GAME_OVER_MSG db 'Game Over! Score: '
GAME_OVER_LEN equ $ - GAME_OVER_MSG
RESTART_MSG db 'Press R to restart or ESC to exit'
RESTART_LEN equ $ - RESTART_MSG
PAUSED_MSG db 'PAUSED - Press P to resume'
PAUSED_LEN equ $ - PAUSED_MSG
SPEED_MSG db 'Speed: '
SPEED_LEN equ $ - SPEED_MSG

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

draw_boundary:
    pusha
    mov ax, 0xb800
    mov es, ax
    
    mov di, (BOUNDARY_TOP * 80 + BOUNDARY_LEFT) * 2
    mov cx, BOUNDARY_RIGHT - BOUNDARY_LEFT + 1
    mov ax, (BOUNDARY_COLOR << 8) | 0xC4
    
top_line:
    stosw
    loop top_line
    
    mov di, (BOUNDARY_BOTTOM * 80 + BOUNDARY_LEFT) * 2
    mov cx, BOUNDARY_RIGHT - BOUNDARY_LEFT + 1
    
bottom_line:
    stosw
    loop bottom_line
    
    ; Draw left boundary
    mov di, (BOUNDARY_TOP * 80 + BOUNDARY_LEFT) * 2
    mov cx, BOUNDARY_BOTTOM - BOUNDARY_TOP + 1
    mov ax, (BOUNDARY_COLOR << 8) | 0xB3
    
left_line:
    mov [es:di], ax
    add di, 160
    loop left_line

    mov di, (BOUNDARY_TOP * 80 + BOUNDARY_RIGHT) * 2
    mov cx, BOUNDARY_BOTTOM - BOUNDARY_TOP + 1
    
right_line:
    mov [es:di], ax
    add di, 160
    loop right_line
    

    mov di, (BOUNDARY_TOP * 80 + BOUNDARY_LEFT) * 2
    mov word [es:di], (BOUNDARY_COLOR << 8) | 0xDA
    
    mov di, (BOUNDARY_TOP * 80 + BOUNDARY_RIGHT) * 2
    mov word [es:di], (BOUNDARY_COLOR << 8) | 0xBF
    
    mov di, (BOUNDARY_BOTTOM * 80 + BOUNDARY_LEFT) * 2
    mov word [es:di], (BOUNDARY_COLOR << 8) | 0xC0
    
    mov di, (BOUNDARY_BOTTOM * 80 + BOUNDARY_RIGHT) * 2
    mov word [es:di], (BOUNDARY_COLOR << 8) | 0xD9
    
    popa
    ret

delay:
    push cx
    push dx
    mov cx, 0x0002
delay_loop:
    mov dx, [speed]
    
delay_inner:
    dec dx
    jnz delay_inner
    dec cx
    jnz delay_loop
    pop dx
    pop cx
    ret

generate_food:
    pusha
retry:
    mov ah, 0x00
    int 0x1A
    
    mov bl, byte [es:0500h]
    xor dl, bl
    
    mov ax, dx
    xor dx, dx
    mov bx, BOUNDARY_BOTTOM - BOUNDARY_TOP - 8
    div bx
    add dl, BOUNDARY_TOP + 4
    mov [food_row], dl
    
    mov ah, 0x2C
    int 0x21
    
    mov al, cl
    mul dl
    xor dx, dx
    mov bx, BOUNDARY_RIGHT - BOUNDARY_LEFT - 8
    div bx
    add dl, BOUNDARY_LEFT + 4
    mov [food_col], dl
    
    mov cl, [snake_length]
    mov ch, 0
    mov si, 0
    
check_collision:
    mov al, [segment_rows + si]
    cmp al, [food_row]
    jne no_collision
    mov al, [segment_cols + si]
    cmp al, [food_col]
    je retry
    
no_collision:
    inc si
    loop check_collision
    
    popa
    ret

draw_food:
    pusha
    mov ax, 0xb800
    mov es, ax
    
    mov al, [food_row]
    mov bl, 80
    mul bl
    add al, [food_col]
    adc ah, 0
    shl ax, 1
    mov di, ax
    
    mov al, FOOD_CHAR
    mov ah, FOOD_COLOR
    mov [es:di], ax
    
    popa
    ret

draw_snake:
    pusha
    mov ax, 0xb800
    mov es, ax
    mov cl, [snake_length]
    mov ch, 0
    mov si, 0

draw_segment:
    mov al, [segment_rows + si]
    mov bl, 80
    mul bl
    add al, [segment_cols + si]
    adc ah, 0
    shl ax, 1
    
    mov di, ax
    mov word [es:di], (SNAKE_COLOR << 8) | '#'
    inc si
    loop draw_segment
    popa
    ret

check_collisions:
    mov al, [segment_rows]
    cmp al, BOUNDARY_TOP
    
    jle collision_detected
    cmp al, BOUNDARY_BOTTOM
    jge collision_detected
    
    mov al, [segment_cols]
    cmp al, BOUNDARY_LEFT
    jle collision_detected
    
    cmp al, BOUNDARY_RIGHT
    jge collision_detected
    
    mov cl, [snake_length]
    dec cl
    jz no_self_collision
    mov ch, 0
    mov si, 1
    
self_check:
    mov al, [segment_rows]
    cmp al, [segment_rows + si]
    jne next_segment
    mov al, [segment_cols]
    cmp al, [segment_cols + si]
    je collision_detected
    
next_segment:
    inc si
    loop self_check
    
no_self_collision:
    ret
    
collision_detected:
    mov byte [game_over], 1
    ret

update_positions:
    mov al, [snake_length]
    dec al
    mov bl, al
    xor bh, bh
    mov al, [segment_rows + bx]
    mov [last_tail_row], al
    mov al, [segment_cols + bx]
    mov [last_tail_col], al

    mov cl, [snake_length]
    dec cl
    mov ch, 0
    
shift_loop:
    mov si, cx
    mov al, [segment_rows + si - 1]
    mov [segment_rows + si], al
    mov al, [segment_cols + si - 1]
    mov [segment_cols + si], al
    dec cx
    jnz shift_loop

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
    jmp check_food
    
move_down:
    inc byte [segment_rows]
    jmp check_food
    
move_left:
    dec byte [segment_cols]
    jmp check_food
    
move_right:
    inc byte [segment_cols]

check_food:
    mov al, [segment_rows]
    cmp al, [food_row]
    jne no_food
    mov al, [segment_cols]
    cmp al, [food_col]
    jne no_food
    
    inc word [score]
    
no_speed_change:
    mov al, [snake_length]
    cmp al, MAX_LENGTH
    jge no_grow
    
    inc byte [snake_length]
    mov al, [snake_length]
    dec al
    mov bl, al
    xor bh, bh
    
    mov al, [last_tail_row]
    mov [segment_rows + bx], al
    mov al, [last_tail_col]
    mov [segment_cols + bx], al
    
no_grow:
    call generate_food
    
no_food:
    ret

display_score:
    pusha
    mov ax, 0xb800
    mov es, ax
    
    mov di, 0
    mov si, score_label
    mov cx, score_label_len
    mov ah, 0x0A
    
score_label_loop:
    lodsb
    stosw
    loop score_label_loop
    
    mov ax, [score]
    mov bx, 10
    mov cx, 0
    
convert_loop:
    xor dx, dx
    div bx
    add dl, '0'
    push dx
    inc cx
    test ax, ax
    jnz convert_loop
    
display_loop:
    pop ax
    mov ah, 0x0A
    stosw
    loop display_loop
    
    mov di, (0 * 80 + 70) * 2
    mov si, SPEED_MSG
    mov cx, SPEED_LEN
    mov ah, 0x0E
    
speed_msg_loop:
    lodsb
    stosw
    loop speed_msg_loop
    
    mov ax, 0xFFFF
    sub ax, [speed]
    shr ax, 12
    inc ax
    add al, '0'
    mov ah, 0x0E
    stosw
    
    popa
    ret

display_timer:
    pusha
    mov ax, 0xb800
    mov es, ax
    
    mov ah, 0x2C
    int 0x21
    
    cmp cl, [last_second]
    je timer_done
    mov [last_second], cl
    
    mov di, (0 * 80 + 50) * 2
    
    mov al, 'T'
    mov ah, 0x0E
    stosw
    mov al, 'i'
    stosw
    mov al, 'm'
    stosw
    mov al, 'e'
    stosw
    mov al, ':'
    stosw
    mov al, ' '
    stosw
    
    mov al, ch
    call display_2digit
    
    mov al, ':'
    mov ah, 0x0E
    stosw

    mov al, cl
    call display_2digit
    
timer_done:
    popa
    ret

display_2digit:

    push ax
    push bx
    push cx
    
    mov ah, 0
    mov bl, 10
    div bl
    
    add al, '0'
    mov ah, 0x0E
    stosw
    
    mov al, ah
    add al, '0'
    stosw
    
    pop cx
    pop bx
    pop ax
    ret

show_game_over:
    pusha
    call clrscr
    call draw_boundary
    
    mov ax, 0xb800
    mov es, ax

    mov di, (10 * 80 + 30) * 2 
    mov si, GAME_OVER_MSG
    mov cx, GAME_OVER_LEN
    mov ah, 0x0C
    
game_over_loop:
    lodsb
    stosw
    loop game_over_loop
    
    mov di, (11 * 80 + 40) * 2 
    mov ax, [score]
    mov bx, 10
    mov cx, 0
    
score_convert:
    xor dx, dx
    div bx
    add dl, '0'
    push dx
    inc cx
    test ax, ax
    jnz score_convert
    
score_display:
    pop ax
    mov ah, 0x0A
    stosw
    loop score_display
    
    mov di, (13 * 80 + 25) * 2
    mov si, RESTART_MSG
    mov cx, RESTART_LEN
    mov ah, 0x07
    
restart_loop:
    lodsb
    stosw
    loop restart_loop
    
    popa
    ret

show_paused:
    pusha
    mov ax, 0xb800
    mov es, ax
    
    mov di, (12 * 80 + 30) * 2
    mov si, PAUSED_MSG
    mov cx, PAUSED_LEN
    mov ah, 0x0E
    
paused_loop:
    lodsb
    stosw
    loop paused_loop
    
    popa
    ret

wait_for_restart:
    ; Wait for R or ESC key
    mov ah, 00h
    int 16h
    
    cmp al, 'r'
    je restart_game
    cmp al, 'R'
    je restart_game
    cmp ah, 01h  ; ESC scan code
    
    je exit_game
    jmp wait_for_restart

restart_game:
    ; Reset game state
    mov byte [segment_rows], 10
    mov byte [segment_rows+1], 10
    mov byte [segment_rows+2], 10
    mov byte [segment_cols], 10
    mov byte [segment_cols+1], 9
    mov byte [segment_cols+2], 8
    mov byte [snake_length], 3
    mov byte [direction], 3
    mov byte [new_direction], 3
    mov word [score], 0
    mov word [speed], 0xAFFF
    mov byte [game_over], 0
    mov byte [paused], 0
    
    call generate_food
    jmp game_loop

exit_game:
    mov ax, 0x4c00
    int 0x21

start:
    call clrscr
    call draw_boundary
    call generate_food

    mov ah, 0x2C
    int 0x21
    mov [last_second], cl

game_loop:
    call delay
    
    ; Check if game over
    cmp byte [game_over], 1
    je near end_game
    
    ; Check if paused
    cmp byte [paused], 1
    je near paused_state
    
    ; Check for key press 
    mov ah, 01h
    int 16h
    jz near no_key
    mov ah, 00h
    int 16h
    
    ; Check for WASD keys
    cmp al, 'w'
    je up_pressed
    cmp al, 's'
    je down_pressed
    cmp al, 'a'
    je left_pressed
    cmp al, 'd'
    je right_pressed
    
    cmp ah, 0x48  ; Up arrow
    je up_pressed
    cmp ah, 0x50  ; Down arrow
    je down_pressed
    cmp ah, 0x4B  ; Left arrow
    je left_pressed
    cmp ah, 0x4D  ; Right arrow
    je right_pressed
    
    cmp al, 'p'
    je p_pressed
    cmp al, 'P'
    je p_pressed
    
    jmp no_key

up_pressed:
    cmp byte [direction], 1
    je no_key
    mov byte [new_direction], 0
    jmp no_key
    
down_pressed:
    cmp byte [direction], 0
    je no_key
    mov byte [new_direction], 1
    jmp no_key
    
left_pressed:
    cmp byte [direction], 3
    je no_key
    mov byte [new_direction], 2
    jmp no_key
    
right_pressed:
    cmp byte [direction], 2
    je no_key
    mov byte [new_direction], 3
    jmp no_key
    
p_pressed:
    xor byte [paused], 1
    jmp no_key
    
no_key:
    mov al, [new_direction]
    mov [direction], al

    call clrscr
    call draw_boundary
    call update_positions
    call check_collisions
    call draw_food
    call draw_snake
    call display_score
    call display_timer
    
    jmp game_loop

paused_state:
    call show_paused
    
    mov ah, 01h
    int 16h
    jz paused_state
    
    mov ah, 00h
    int 16h
    
    cmp al, 'p'
    je unpause_game
    cmp al, 'P'
    je unpause_game
    
    jmp paused_state

unpause_game:
    mov byte [paused], 0
    jmp game_loop

end_game:
    call show_game_over
    call wait_for_restart

