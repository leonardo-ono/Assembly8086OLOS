	bits 16
	org 100h

start_kernel:
	call install_olos_mm_handler ; int 30h
	call install_olos_fs_handler ; int 31h	
	; call install_olos_process_handler ; int 32h	
	call install_olos_cmd_handler ; int 21h

	; clear screen
	mov ah, 0
	mov al, 3
	int 10h

	push welcome_msg
	call print_str
	add sp, 2

	mov ah, 4ch ; call cmd (prompt)
	int 21h

	%include "mem.asm"
	%include "fat12.asm"
	%include "process.asm"
	%include "cmd.asm"

kernel_data:
	welcome_msg db "Welcome to OLOS vs 0.0.1 [28/12/2018]", 13, 10, 13, 10
               db "Developed by Leonardo Ono (ono.leo@gmail.com)", 13, 10, 13, 10, 0

