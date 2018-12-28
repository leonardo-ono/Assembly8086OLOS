	bits 16
	org 100h

start:
   mov bx, data1
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

nextFile:
   mov dl, 0
   mov cx, 11

   mov al,[data1+si+11]
   cmp al,0fh
   jz preparaParaProximoArquivo2
   jmp short next

preparaParaProximoArquivo2:
   add si, 11
   jmp short preparaParaProximoArquivo

next:
   mov ah, 0eh
   mov al, [data1+si]

   cmp dl, 1
   jz naoVerificaPrimeiroChar
   mov dl, 1
   cmp al,0
   jz fim

naoVerificaPrimeiroChar:

   int 10h
   inc si

   cmp cl, 4
   jnz cont

   mov ah, 0eh
   mov al, ' '
   int 10h

cont:
   loop next

   mov ah, 0eh
   mov al, 13
   int 10h
   mov ah, 0eh
   mov al, 10
   int 10h

preparaParaProximoArquivo:

   inc bx
   cmp bx, 128
   jz fim

   add si,21
   jmp nextFile

fim:
   mov ah, 0eh
   mov al, 13
   int 10h
   mov ah, 0eh
   mov al, 10
   int 10h

   mov ah, 4ch
   int 21h

; --- aqui vao os dados do arquivo
data1:


