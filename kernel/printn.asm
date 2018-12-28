bits 16
org 100h

start:
		mov word [lba], 0

	.next_lba:
; void convert_to_chs(int lba, int hpc, int spt, int *c, int *h, int *s);
		push word s
		push word h
		push word c
		push word [spt]
		push word [hpc]
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
		
		mov ah, 0
		int 16h
		
		cmp al, 27
		jz .exit_process
		
		call _println
		
		inc word [lba]
		cmp word [lba], 2880
		jb .next_lba
		
	.exit_process:
		mov ah, 4ch
		int 21h

data:
	lba_msg db "lba: ", 0	
	cylinders_msg db "cylinders: ", 0	
	headers_msg db "headers: ", 0	
	sectors_msg db "sectors: ", 0	
	
	lba dw 0
	hpc dw 2
	spt dw 18
	
	c dw 0
	h dw 0
	s dw 0
	
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
		
