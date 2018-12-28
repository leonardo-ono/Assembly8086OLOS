	bits 16
	org 100h

start:
		push msg
		call print_str
		add sp, 2

		mov ah, 4ch
		int 21h

data:
	msg db 13, 10, "     THANKS FOR WATCHING     ", 13, 10
       db 13, 10, "             AND             ", 13, 10
       db 13, 10, "   HAPPY NEW YEAR -> 2019 :) !", 13, 10, 13, 10, 0
 
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

