		bits 16

		OLOS_CMD_INT equ 21h

olos_cmd_data:
	cmd_cylinders dw 0
	cmd_headers   dw 0
	cmd_sectors   dw 0
	cmd_c         dw 0
	cmd_h         dw 0
	cmd_s         dw 0

install_olos_cmd_handler:
		push ax
		push es
		cli
		mov ax, 0
		mov es, ax
		mov ax, cs
		mov word [es:4 * OLOS_CMD_INT + 2], ax
		mov word [es:4 * OLOS_CMD_INT], olos_cmd_handler
		sti
		pop es
		pop ax
		ret

olos_cmd_buffer:
		times 256 db ' '
		db 0

clear_cmd_buffer:
		push ax
		push cx
		push di
		push es
		mov cx, 256
		mov ax, cs
		mov es, ax
		mov di, olos_cmd_buffer
		mov al, ' '
		rep stosb
		pop es
		pop di
		pop cx
		pop ax
		ret

olos_cmd_stack:
		times 256 db 0
	stack_top:

; int 21h
olos_cmd_handler:
		cmp ah, 4ch
		jz .start_cmd

		iret

	.start_cmd:
		mov ax, cs
		mov ds, ax
		mov es, ax
		mov ss, ax
		mov sp, stack_top

		call cmd_read_drive_parameters
		call clear_cmd_buffer

		mov ah, 0eh
		mov al, '>'
		int 10h

		mov di, 0
	.next_char:
		mov ah, 0
		int 16h

		cmp al, 13
		jz .confirm

		cmp al, 8
		jz .back_space

		;cmp di, 78
		cmp di, 8 ; for now, allows only first 8 bytes of a file
		jz .next_char

		cmp al, 27
		jz .end

		call check_valid_char
		jnc .next_char

		mov ah, 0eh
		;add al, '0'
		int 10h

		mov [olos_cmd_buffer + di], al

		inc di
		jmp .next_char

	.back_space:
		cmp di, 0
		jz .next_char

		mov ah, 03h ; get cursor position
		mov bh, 0
		int 10h
		sub dl, 1 ; dl = column
		mov ah, 02h ; set cursor position
		int 10h
		mov ah, 0eh
		mov al, ' ' ; erase
		int 10h
		;sub dl, 1 ; dl = column
		mov ah, 02h ; set cursor position
		int 10h
		dec di
		mov byte [olos_cmd_buffer + di], ' '
		jmp .next_char

	.confirm:
		call print_ln

; ----------------
;		mov ah, 0eh
;		mov al, ':'
;		int 10h

;		push olos_cmd_buffer
;		call print_str
;		add sp, 2

;		call print_ln
; ----------------

		call execute_command

		mov ah, 4ch
		int 21h

		; jmp olos_cmd_handler

	.end:
		ret


print_ln:
		push ax
		mov ah, 0eh
		mov al, 13 ; cr
		int 10h
		mov ah, 0eh
		mov al, 10 ; ln
		int 10h
		pop ax
		ret

; void print_n(unsigned int value);
print_n:
		push bp
		mov bp, sp

		push ax
		push bx
		push cx
		push dx
  
		mov cx, 0
	.next_digit:
		mov dx, 0
		mov ax, [bp + 4]
		mov bx, 10
		div bx
		mov [bp + 4], ax
		push dx
		inc cx
		cmp word [bp + 4], 0
		ja .next_digit
	.print_next_digit:        
		pop ax
		mov ah, 0eh
		add al, '0'
		int 10h
		loop .print_next_digit
    	.exit:

		pop dx
		pop cx
		pop bx
		pop ax

		pop bp
		ret

; print_str(unsigned char *text);
print_str:
		push bp
		mov bp, sp

		push ax
		push bx
		push si

		mov bx, [bp + 4]
		mov si, 0
	.next_char:
		mov ah, 0eh
		mov al, [bx + si]
		cmp al, 0
		jz .end
		int 10h
		inc si
		jmp .next_char
	.end:

		pop si
		pop bx
		pop ax

		pop bp
		ret

; in:
;	di = string address
; out:
;  carry flag 1 = match
;             0 = mismatch
compare_cmd_str:
		push ax
		push cx
		push si
		push di
		push ds
		push es

		mov ax, cs
		mov ds, ax
		mov es, ax

		cld ; forward direction

		mov cx, 8
		mov si, olos_cmd_buffer
		; mov di, buffer2
		repe cmpsb
		jne .mismatch
	.match:
		;push .match_msg
		;call print_str
		;add sp, 2
		stc
		jmp .end

	.mismatch:
		;push .mismatch_msg
		;call print_str
		;add sp, 2
		clc

	.end:
		pop es
		pop ds
		pop di
		pop si
		pop cx
		pop ax
		ret
	.match_msg:
		db "cmd match !", 13, 10, 0
	.mismatch_msg:
		db "cmd mismatch !", 13, 10, 0

; in: 
;		al = ascii code
; out:
;     al = ascii code (to upper case)
;		carry flag = 1 invalid
;                  0 valid
check_valid_char:
		push bx
		mov bx, 0
	.next_valid_char:
		mov ah, [.valid_chars + bx]
		cmp ah, al
		jz .is_valid
		cmp ah, 1
		jz .is_invalid
		inc bx
		jmp .next_valid_char
	.is_invalid:
		clc
		jmp .end
	.is_valid:
		cmp bx, 26
		jnb .is_valid_already_upper
		sub al, 32 ; to upper case
	.is_valid_already_upper:
		stc
	.end:
		pop bx
		ret
	.valid_chars:
		db "abcdefghijklmnoprqstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_", 1

cmd_read_drive_parameters:
		push ax
		push di
		push es

		mov ax, 0
		mov es, ax
		mov di, 0
		mov ah, 8h
		mov dl, 0; dl already set // todo floppy
		int 13h
	
		mov ax, 0
		mov al, dh
		inc ax
		mov [cmd_headers], ax

		mov ax, cx
		and ax, 111111b ; al and 00111111b contem os 6 bits para os setores
		mov [cmd_sectors], ax

		mov ax, cx ; ch contem os 8 low bits 2 al and 11000000b contem os 2 high bits 
		shr al, 6
		xchg ah, al
		inc ax
		mov [cmd_cylinders], ax

		pop es
		pop di
		pop ax
		ret

execute_command:
		push ax
		push bx
		push cx
		push dx
		push si
		push di
		push es

		mov bx, .data1
		mov ax, cs
		mov es, ax
		mov ah, 02h ; no funcao
		mov al, 14 ; numero de setores a ler
		mov ch, 0 ; cilinder
		mov cl, 2 ; sector
		mov dh, 1 ; head
		mov dl, 0 ; 0=drive A
		int 13h

		mov bx, 0
		mov si, 0
	.nextFile:
		mov dl, 0
		mov cx, 11
		mov al, [.data1 + si + 11]
		cmp al,0fh
		jz .preparaParaProximoArquivo2
		jmp short .valid_file_found
	.preparaParaProximoArquivo2:
		add si, 11
		jmp short .preparaParaProximoArquivo
	.valid_file_found:
		mov di, .data1
		add di, si
		call compare_cmd_str
		jc .execute_cmd_file

	.next_file_char:
		mov ah, 0eh
		mov al, [.data1 + si]
		cmp dl, 1
		jz .naoVerificaPrimeiroChar
		mov dl, 1
		cmp al,0
		jz .fim
	.naoVerificaPrimeiroChar:
		; int 10h
		inc si
		cmp cl, 4
		jnz .cont

		; mov ah, 0eh
		; mov al, ' '
		; int 10h

	.cont:
		loop .next_file_char
		; call print_ln

	.preparaParaProximoArquivo:
		inc bx
		cmp bx, 224
		jz .fim
		add si, 21
		jmp .nextFile

	.execute_cmd_file:
		call read_drive_parameters

		;push .executing_cmd_msg
		;call print_str
		;add sp, 2

		; load fat table
		mov bx, fat_table
		mov ax, cs
		mov es, ax
		mov ah, 02h ; no funcao
		mov al, 9 ; numero de setores a ler
		mov ch, 0 ; cilinder
		mov cl, 2 ; sector
		mov dh, 0 ; head
		mov dl, 0 ; 0=drive A
		int 13h

;---------------
;		mov cx, 16
;		mov bx, 0
;	.next_fat:
;		mov ah, 0
;		mov al, [fat_table + 2 + bx]
;		push ax
;		call print_n
;		add sp, 2
;
;		mov ah, 0eh
;		mov al, ' '
;		int 10h
;
;		inc bx
;		loop .next_fat
;---------------

		mov word [.program_load_seg], 17e0h ; deixa 64k entre o kernel e o programa

		mov ax, [.data1 + si + 26] ; 26 = offset first logical cluster

	.next_sector:
		mov dx, [.program_load_seg]
		mov es, dx
		mov bx, 100h ; COM executable offset

		;call print_ln
		;push .loading_cmd_msg
		;call print_str
		;add sp, 2
		;push ax
		;call print_n
		;add sp, 2

		; in:
		;	ax = lba
		;  cl = number of sectors
		;  es:bx = address where data will be loaded
		mov cl, 1
		push ax
		add ax, 31
		call read_sector
		pop ax

		call get_next_cluster

		add word [.program_load_seg], 32 ; next sector in memory

		cmp ax, 4088 ; last cluster in a file ?
		jb .next_sector

	.start_program_execution:
		mov ax, 17e0h 
		mov ds, ax
		mov es, ax
		mov ss, ax
		mov sp, 0fffeh
		jmp 17e0h:100h ; start execution

		;push 100h
		;call print_str
		;add sp, 2

	.fim:

	.invalid_command:
		push .invalid_cmd_msg
		call print_str
		add sp,2 

		pop es
		pop di
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	.loading_cmd_msg:
		db " reading cluster: ", 0
	.executing_cmd_msg:
		db "executing cmd ...", 13, 10, 0
	.invalid_cmd_msg:
		db "invalid command !", 13, 10, 0

	; --- aqui vao os dados do arquivo
	.data1:
		times 7168 db 0
	.program_load_seg:
		dw 0

fat_table:
		times (9 * 512) db '.'

; in:
;	ax = position
; in:
;	ax = next cluster
get_next_cluster:
		push bx
		push cx
		push dx
		push si

		mov si, ax ; si = copy
		mov cx, ax
		and cx, 1
		cmp cx, 1
		jz .odd

	.even:
		mov cx, 3
		mul cx ; dx:ax = ax * cx
		shr ax, 1
		inc ax
		mov bx, ax
		mov ah, [fat_table + bx]
		and ah, 0fh
		mov al, [fat_table + bx - 1]
		jmp .end

	.odd:
		mov cx, 3
		mul cx ; dx:ax = ax * cx
		shr ax, 1
		mov bx, ax
		mov cl, [fat_table + bx]
		shr cl, 4
		mov ah, 0
		mov al, [fat_table + bx + 1]
		shl ax, 4
		add al, cl

	.end:
		pop si
		pop dx
		pop cx
		pop bx
		ret

