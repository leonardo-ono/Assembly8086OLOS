; reference: DOS interrupts - http://spike.scu.edu.au/~barry/interrupts.html
		bits 16

		OLOS_FS_INT equ 31h

install_olos_fs_handler:
		push ax
		push es
		call read_drive_parameters
		cli
		mov ax, 0
		mov es, ax
		mov ax, cs
		mov word [es:4 * OLOS_FS_INT + 2], ax
		mov word [es:4 * OLOS_FS_INT], olos_fs_handler
		sti
		pop es
		pop ax
		ret
			
; int 31h
olos_fs_handler:
		pusha
		push ds
		push es
		push ss

		;mov ax, 7e0h
		;mov ds, ax
		;mov es, ax
		;mov ss, ax
		;mov sp, 0fffeh

		mov ah, 0eh
		mov al, '='	
		int 10h		

		cmp ah, 60h
		jnz .end
		; ah = 60h
		call printRootFiles

	.end:
		pop ss
		pop es
		pop ds
		popa
		iret


fs_data:
	drive db 0
	cylinders dw 0
	headers   dw 0
	sectors   dw 0
	c dw 0
	h dw 0
	s dw 0
	lba dw 0

init_fs:

read_drive_parameters:
		push ax
		push di
		push es

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

		pop es
		pop di
		pop ax
		ret

create_file_manager:

destroy_file_manager:

get_current_directory:

set_current_directory:

create_subdirectory:

remove_subdirectory:

get_files:

get_free_disk_space:

file_exists:

file_create:

file_open:

file_seek:

file_read:

file_write:

file_close:

file_delete:

file_rename:

; ah = 60h
printRootFiles:
		mov bx, .data1
		mov ax, cs
		mov es, ax
		mov ah, 02h ; no funcao
		mov al, 9 ; numero de setores a ler
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
		mov al,[.data1+si+11]
		cmp al,0fh
		jz .preparaParaProximoArquivo2
		jmp short .next
	.preparaParaProximoArquivo2:
		add si, 11
		jmp short .preparaParaProximoArquivo
	.next:
		mov ah, 0eh
		mov al, [.data1 + si]
		cmp dl, 1
		jz .naoVerificaPrimeiroChar
		mov dl, 1
		cmp al,0
		jz .fim
	.naoVerificaPrimeiroChar:
		int 10h
		inc si
		cmp cl, 4
		jnz .cont
		mov ah, 0eh
		mov al, ' '
		int 10h
	.cont:
		loop .next
		mov ah, 0eh
		mov al, 13
		int 10h
		mov ah, 0eh
		mov al, 10
		int 10h
	.preparaParaProximoArquivo:
		inc bx
		cmp bx, 128
		jz .fim
		add si, 21
		jmp .nextFile
	.fim:
		ret
	; --- aqui vao os dados do arquivo
	.data1:
		times 7168 db 0

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

; in:
;	ax = lba
;  cl = number of sectors
;  es:bx = address where data will be loaded
read_sector:
		pusha
		push ds
		push es

		mov word [lba], ax ; ex ax=34
		; void convert_to_chs(int lba, int hpc, int spt, int *c, int *h, int *s);
		push word s
		push word h
		push word c
		push word [sectors] ; spt
		push word [headers] ; hpc
		push word [lba]
		call _convert_lba_to_chs
		add sp, 12

		; read sector
		;mov ax, 7e0h
		;mov es, ax
		;mov bx, 100h ; load so at 07e0:0100 
		mov ah, 2
		mov al, cl ; number of sectors to read
		mov ch, [c]
		mov dh, [h]
		mov cl, [s]
		mov dl, [drive]
		int 13h

		;mov ah, 0eh
		;mov al, '*'
		;int 10h

		pop es
		pop ds
		popa
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
		pusha
		
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
		mov word [bx], ax ; *s = sector
		
		popa
		pop bp
		ret




