		bits 16

		BYTES_PER_BLOCK equ 16
		MEMORY_BLOCKS_COUNT equ 38876
		OS_INT equ 30h

install_olos_mm_handler:
		push ax
		push es
		cli
		mov ax, 0
		mov es, ax
		mov ax, cs
		mov word [es:4 * OS_INT + 2], ax
		mov word [es:4 * OS_INT], os_handler
		call resetMemoryAllocationTable
		sti
		pop es
		pop ax
		ret
			
; int 30h
os_handler:
		cli
		push ax

		cmp ah, 48h
		jnz .next_function_1		

		; in:
		; 	ah = 48h (malloc)
		; 	cx = number of memory paragraphs requested
		; out:
		; 	es = segment address -> es:0
		;	es = 0 -> error
		call malloc

		mov ah, 0eh
		mov al, '1'
		int 10h

		jmp .end

	.next_function_1:
		cmp ah, 49h
		jnz .next_function_1		

		; in:
		; 	ah = 49h (free)
		; 	es = segment address -> es:0
		; out:
		;	ax = 1 successful
		;       0 error 
		call free

		mov ah, 0eh
		mov al, '2'
		int 10h

	.end:
		
		mov ah, 0eh
		mov al, 'X'
		int 10h

		pop ax
		sti
		iret
		
; tabela de alocacao de memoria localizada em 0050:0000 (9719 bytes)
resetMemoryAllocationTable:
		push ax
		push cx
		push di
		push es
		
		mov ax, 50h
		mov es, ax ; allocation table located at 0050:0000
		mov ax, 0
		mov di, 0
		mov cx, MEMORY_BLOCKS_COUNT / 4
		rep stosb 
		
		pop es
		pop di
		pop cx
		pop ax
		ret
	
; in:
;	ax = block index (0 ~ MEMORY_BLOCKS_COUNT)
; out:
;	bl = status:
;		0 = free
;               1 = used first block
;               3 = used contiguous block
getMemoryStatus:
		push ax
		push cx
		push dx
		push es

		mov dx, 0
		; mov ax, 1 ; block index
		mov cx, 4
		div cx ; ax=quot dx=remainder
		
		mov bx, ax; bx = index
		shl dl, 1 ; dx = (position % 4) * 2
		
		mov ax, 50h
		mov es, ax
		mov al, [es:bx] ; al = [0050:bx]
		
		mov cl, dl
		shr al, cl
		and al, 011b
		mov bl, al

		pop es
		pop dx
		pop cx
		pop ax
		ret

; in:
;	ax = block index (0 ~ MEMORY_BLOCKS_COUNT)
;	bl = status 
;		0 = free
;               1 = used first block
;               3 = used continuous block
setMemoryStatus:
		push ax
		push bx
		push cx
		push dx
		push si
		push es

		mov dx, 0
		; mov ax, 5 ; block index
		; mov bl, 3 ; memory status
		mov cx, 4
		div cx ; ax=quot dx=remainder
		
		mov si, ax; si = index
		shl dl, 1 ; dl = shift = (position % 4) * 2

		mov ax, 50h
		mov es, ax
		
		mov ah, 11b
		mov cl, dl
		shl ah, cl
		not ah ; ah = ~(3 << shift)
		
		mov al, [es:si]
		and al, ah
		
		shl bl, cl
		or al, bl
		mov [es:si], al

		pop es
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	
; referencia: https://wiki.osdev.org/Memory_Map_(x86)
;                        07E0:0000~9FBC:0000 -> 38876 blocos de 16 bytes = 622016 bytes totais disponiveis
; -1 bloco (pois 0 = memoria nao disponivel) -> 38875 blocos de 16 bytes = 622000 bytes livres
;
; in:
; 	ah = 48h
; 	cx = number of memory paragraphs requested
; out:
; 	es = segment address -> es:0
;	es = 0 -> error
malloc:
		push ax
		push bx
		push cx
		push dx
		push si
		push di
		
		mov ax, 0
		mov es, ax
		
		mov ax, 1
	malloc_next_block:
		call getMemoryStatus
		cmp bl, 0  ; bl = memory status
		jnz malloc_continue_1
	malloc_first_free_block_found:
		mov di, ax
		add di, cx ; di = lastBlock = i + requiredBlocks
		cmp di, MEMORY_BLOCKS_COUNT
		ja malloc_end ; if (lastBlock > maxBlocks) -> no memory available

		mov si, ax
		inc si
	malloc_next_block_2:
		push ax
		mov ax, si
		call getMemoryStatus
		pop ax

		cmp bl, 0  ; bl = memory status
		jnz malloc_continue_1

		inc si
		cmp si, di ; di = last block
		jb malloc_next_block_2	
	
	malloc_free_contiguos_block_found:
		; mov ax, ax ; ax ja contem o first free block index
		mov bl, 1
		call setMemoryStatus ; used first block
		
		mov si, ax
		inc si
	malloc_next_block_3:
		push ax
		mov ax, si
		mov bl, 3
		call setMemoryStatus ; used contiguos block
		pop ax
		
		inc si
		cmp si, di ; di = last block
		jb malloc_next_block_3

	malloc_return_free_memory_position:
		add ax, 7e0h
		mov es, ax
		jmp malloc_end

	malloc_continue_1:
		inc ax
		cmp ax, MEMORY_BLOCKS_COUNT
		jb malloc_next_block		

	malloc_end:
		pop di
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret		


; in:
; 	ah = 49h
; 	es = segment address -> es:0
; out:
;	ax = 1 successful
;       0 error 
free:
		push bx
	free_init:
		mov ax, es
		sub ax, 7e0h ; ax = memory block index
		call getMemoryStatus
		cmp bl, 1  ; bl = memory status
		jnz free_not_used_first_block
	free_release_next_block:
		mov bl, 0
		call setMemoryStatus
		inc ax
		cmp ax, MEMORY_BLOCKS_COUNT
		jae free_success
		call getMemoryStatus
		cmp bl, 3
		jz free_release_next_block
	free_success:
		mov ax, 1
		jmp free_end
	free_not_used_first_block:
		mov ax, 0
	free_end:
		pop bx
		ret
		


