	bits 16
	org 100h

start:
	mov ah, 0
	mov al, 3
	int 10h

	mov ah, 4ch
	int 21h
