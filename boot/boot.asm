org 7c00h

		jmp short data_start
		nop

		; Bios Parameter Block
		db 0x4D, 0x53, 0x44, 0x4F, 0x53, 0x35, 0x2E, 0x30, 0x00
		db 0x02, 0x01, 0x01, 0x00, 0x02, 0xE0, 0x00, 0x40, 0x0B, 0xF0, 0x09, 0x00
		db 0x12, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
		db 0x00, 0x00, 0x29, 0x04, 0xB9, 0x2C, 0x6C, 0x4E, 0x4F, 0x20, 0x4E, 0x41
		db 0x4D, 0x45, 0x20, 0x20, 0x20, 0x20, 0x46, 0x41, 0x54, 0x31, 0x32, 0x20
		db 0x20, 0x20

data_start:
	jmp short boot_loader

	drive db 0

	cylinders dw 0
	headers   dw 0
	sectors   dw 0

	lba dw 0
	c   dw 0
	h   dw 0
	s   dw 0

	lba_msg db "lba: ", 0	
	cylinders_msg db "cylinders: ", 0	
	headers_msg   db "  headers: ", 0	
	sectors_msg   db "  sectors: ", 0	

boot_loader:
	.setup_registers:
		mov ax, 50h
		mov ss, ax
		mov sp, 1024

		mov ax, cs
		mov ds, ax

		mov [drive], dl

	.read_drive_parameters:
		mov ax, 0
		mov es, ax
		mov di, 0
		mov ah, 8h
		; dl already set
		int 13h
		
		mov ax, 0
		mov al, dh
		inc ax
		mov [headers], ax

		mov ax, cx
		and ax, 111111b ; al and 00111111b contem os 6 bits para os setores
		mov [sectors], ax

		mov ax, cx ; ch contem os 8 low bits 2 al and 11000000b contem os 2 high bits 
		shr al, 6
		xchg ah, al
		inc ax
		mov [cylinders], ax

;	.print_drives_info:
;		call _println
;
;		push cylinders_msg
;		call _print_str
;		add sp, 2
;		push word [cylinders]
;		call _print_n
;		add sp, 2
;		call _println
;
;		push headers_msg
;		call _print_str
;		add sp, 2
;		push word [headers]
;		call _print_n
;		add sp, 2
;		call _println
;
;		push sectors_msg
;		call _print_str
;		add sp, 2
;		push word [sectors]
;		call _print_n
;		add sp, 2
;		call _println
;
		mov word [lba], 34
	.read_sectors:
		; void convert_to_chs(int lba, int hpc, int spt, int *c, int *h, int *s);
		push word s
		push word h
		push word c
		push word [sectors] ; spt
		push word [headers] ; hpc
		push word [lba]
		call _convert_lba_to_chs
		add sp, 12

		push word lba_msg
		call _print_str
		add sp, 2
		push word [lba]
		call _print_n
		add sp, 2
		call _println

		push word cylinders_msg
		call _print_str
		add sp, 2
		push word [c]
		call _print_n
		add sp, 2
		call _println

		push word headers_msg
		call _print_str
		add sp, 2
		push word [h]
		call _print_n
		add sp, 2
		call _println

		push word sectors_msg
		call _print_str
		add sp, 2
		push word [s]
		call _print_n
		add sp, 2
		call _println

		mov ax, 7e0h
		mov es, ax
		mov bx, 100h ; load so at 07e0:0100 
		mov ah, 2
		mov al, 60 ; number of sectors to read
		mov ch, [c]
		mov dh, [h]
		mov cl, [s]
		mov dl, [drive]
		int 13h

	;.wait_for_key:
	;	mov ah, 0
	;	int 16h

	.execute_os:
		mov ax, 7e0h
		mov ds, ax
		mov es, ax
		mov ss, ax
		mov sp, 0fffeh
		jmp 7e0h:100h


		hlt

; void println();
_println:
		mov ah, 0eh
		mov al, 13 ; cr
		int 10h
		mov ah, 0eh
		mov al, 10 ; ln
		int 10h
		ret

; void print_n(unsigned int value);
_print_n:
		push bp
		mov bp, sp  
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
		pop bp
		ret

; print_str(unsigned char *text);
_print_str:
		push bp
		mov bp, sp
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
		pop bp
		ret

; C = LBA / (HPC * SPT)
; H = (LBA / SPT) % HPC
; S = (LBA % SPT) + 1		
; void convert_to_chs(int lba, int hpc, int spt, int *c, int *h, int *s);
_convert_lba_to_chs:
		push bp
		mov bp, sp
		%define lba   [bp + 4]
		%define hpc   [bp + 6]
		%define spt   [bp + 8]
		%define c_ptr [bp + 10]
		%define h_ptr [bp + 12]
		%define s_ptr [bp + 14]
		
		mov ax, hpc
		mov bx, spt
		mul bl
		mov bx, ax ; bx = (hpc * spt)
		
		mov dx, 0
		mov ax, lba
		div bx ; ax = cylinder
		
		mov bx, c_ptr
		mov word [bx], ax ; *c = cylinder
		
		mov ax, lba
		mov bx, spt
		div bl 
		mov ah, 0 ; ax = (lba / spt)
		mov bx, hpc
		div bl
		mov al, 0
		xchg ah, al ; ax = header = (lba / spt) % hpc
		
		mov bx, h_ptr
		mov word [bx], ax ; *h = header
		
		mov ax, lba
		mov bx, spt
		div bl ; ah = (lba % spt)
		mov al, 0
		xchg ah, al
		inc ax ; ax = sector = (lba % spt) + 1
		
		mov bx, s_ptr
		mov word [bx], ax ; *s = header
		
		pop bp
		ret

	times 510-($-$$) db 0
	dw 0aa55h
