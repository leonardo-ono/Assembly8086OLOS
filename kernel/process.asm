


	%define FIX_CODE_SIZE_IN_PARAGRAPHS 32
	%define START_OFFSET 256

	org START_OFFSET

fix_exe_segs:
	mov ax, cs
	add ax, FIX_CODE_SIZE_IN_PARAGRAPHS ; soma os paragrafos do FIX_CODE e vai apontar para exe_header
	add ax, [exe_header + 8] ; soma "number of paragraphs in the header" que aponta de fato para inicio do programa (depois do header do executavel)

	add [exe_header + 14], ax ; fix ss in the exe_header
	add [exe_header + 22], ax ; fix cs in the exe_header

; corrige o segment da tabela de relocacao
	mov bx, [exe_header + 24] ; offset of the first relocation item in the file
	mov cx, [exe_header + 6] ; number of relocations entries after header
next_relocation:
	add [bx + exe_header + 2], ax
	mov dx, [bx + exe_header + 2] ; segmento de relocacao
	mov es, dx
	mov di, [bx + exe_header] ; offset de relocacao
	add [es:di], ax
	add bx, 4
	loop next_relocation

set_init_regs:
	mov dx, [exe_header + 14] ; ss
	mov ss, dx
	mov sp, [exe_header + 16] ; set sp

	jmp far [exe_header + 20]

	mov ah, 4ch
	int 21h

	; times (16 * FIX_CODE_SIZE_IN_PARAGRAPHS - START_OFFSET)-($-$$) db 90 ; preenche o FIX_CODE ate completar o valor especificado em FIX_CODE_SIZE_IN_PARAGRAPHS

exe_header:
	; incbin "test.exe"
