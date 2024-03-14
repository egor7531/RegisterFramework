.model tiny
.code
.286
org 100h

;Consts
;--------------------------------------------------------------------------------------------
LEFT_UP_X           = 10		            
LEFT_UP_Y           = 5 	                ; coordinates of the upper-left corner
RIGHT_DOWN_X        = 22		            
RIGHT_DOWN_Y        = 18                    ; coordinates of the lower right corner

LEFT_UP             = 0c9h      	        ; '╔'      	<----------------------------    
HOR_LINE            = 0cdh      	        ; '═' 									|
RIGHT_UP            = 0bbh      	        ; '╗'									| Style
VER_LINE            = 0bah      	        ; '║'									|
RIGHT_DOWN          = 0bch      	        ; '╝'									|
LEFT_DOWN           = 0c8h 		            ; '╚'		<----------------------------

VIDEO_MEM_ADDRESS	= 0b800h
SPACE				= 20h			        ; ' '
COLOR_FRAME 		= 0eh			        ; background = black; color_of_symbol = yellow
COLOR_SYMBOL		= 04h					; background = black; color_of_symbol = red
COUNT_REGS			= 12
;--------------------------------------------------------------------------------------------

Start:    
;keyboard 	
	
            mov ax, 3509h
            int 21h                                     ;es:[bx] - address of 09h interrupt
            mov old09ofs, bx
            mov bx, es
            mov old09seg, bx

            push 0
            pop es
            mov bx, 09h*4
            mov WORD PTR es:[bx], offset new09
            push cs
            pop ax
            mov es:[bx+2], ax 
;timer	
            mov ax, 3508h
            int 21h                                     ;es:[bx] - address of 09h interrupt
            mov old08ofs, bx
            mov bx, es
            mov old08seg, bx

            push 0
            pop es
            mov bx, 08h*4
            mov WORD PTR es:[bx], offset new08
            push cs
            pop ax
            mov es:[bx+2], ax 
;save code            
            mov ax, 3100h   
            mov dx, offset EOP
            shr dx, 4
            inc dx
            int 21h

;--------------------------------------------------------------------------------------------
; New 09h interrupt handling procedure
; Entry: - 
; Returns: 
;--------------------------------------------------------------------------------------------
new09       proc

            push ax

            in al, 60h
            
            cmp al, 29h                  ; '`' = 29h                              
            je FrameOn

            cmp al, 02h                  ; '1' = 02h                              
            je FrameOff
            
            mov al, 20h                  ; send End-Of-Interrupt signal
            out 20h, al                  ; to the 8259 Interrupt Controller
            
            jmp Return 

FrameOff:   mov to_draw, 0
            jmp Exit1

FrameOn:    mov to_draw, 1

Exit1:      in al, 61h
            or al, 80h
            out 61h, al
            in al, 61h
            and al, not 80h            
            out 61h, al
            
            mov al, 20h                 
            out 20h, al                 
            
Return:     pop ax

        	db 0eah
old09ofs    dw 0
old09seg    dw 0

new09       endp

;--------------------------------------------------------------------------------------------
; New 08h interrupt handling procedure
; Entry: - 
; Returns: '`' - calling a frame with values of all registers
;--------------------------------------------------------------------------------------------
new08       proc

            cmp to_draw, 1
            je PopoutFrame

            jmp Exit2 

PopoutFrame:
		    push ax bx cx dx si di es

            call remember_regs
            
            call draw_frame
            call show_regs

            pop es di si dx cx bx ax
            
Exit2:      db 0eah
            old08ofs    dw 0
            old08seg    dw 0

new08       endp

;--------------------------------------------------------------------------------------------
; Remember the initial values of all registers in an array
; Entry:   -
; Assumes: 
; Returns: filled array "regs"
;--------------------------------------------------------------------------------------------
remember_regs		proc
					mov copy, bx
					xor bx, bx 
					mov regs[bx], ax

                    mov bx, copy
                    mov copy, si
                    mov si, 2
                    mov regs[si], bx

                    mov si, copy
                    mov bx, 4
					mov regs[bx], cx

                    add bx, 2
					mov regs[bx], dx

                    add bx, 2
					mov regs[bx], si

                    add bx, 2
					mov regs[bx], di

                    add bx, 2
					mov regs[bx], bp

                    add bx, 2
					mov regs[bx], sp

                    add bx, 2
					mov regs[bx], ds

                    add bx, 2
					mov regs[bx], es

                    add bx, 2
					mov regs[bx], ss

                    add bx, 2
					mov regs[bx], cs

                    ret
remember_regs		endp

;--------------------------------------------------------------------------------------------
; Draws a frame at the specified coordinates with double borders
; Entry:   -
; Assumes: Show frame in video memory
; Returns: -
;--------------------------------------------------------------------------------------------
draw_frame          proc

					push VIDEO_MEM_ADDRESS
					pop es
					
			        mov di, (LEFT_UP_Y * 80 + LEFT_UP_X) * 2        ; the initial address of the meta where you need to start drawing a frame

			        mov ah, COLOR_FRAME
			        mov al, SPACE				
			
			        mov bx, RIGHT_DOWN_Y - LEFT_UP_Y + 1
			        mov cx, RIGHT_DOWN_X - LEFT_UP_X + 1

			        xor si, si

Weight:		        stosw										
			        loop Weight								        ; while(cx--) {es:[di] = ax; di += 2;}

Height:		        mov cx, RIGHT_DOWN_X - LEFT_UP_X + 1
			        add di, (80 - (RIGHT_DOWN_X - LEFT_UP_X + 1)) * 2

			        inc si
			        cmp si, bx										; if(si != bx) Weight;
			        jne Weight										; else 		   Return;

Corners:			mov di, (LEFT_UP_Y * 80 + LEFT_UP_X) * 2
					mov al, LEFT_UP 
					stosw 	

					mov di, (LEFT_UP_Y * 80 + RIGHT_DOWN_X) * 2
					mov al, RIGHT_UP 
					stosw	

					mov di, (RIGHT_DOWN_Y * 80 + LEFT_UP_X) * 2
					mov al, LEFT_DOWN
					stosw

					mov di, (RIGHT_DOWN_Y * 80 + RIGHT_DOWN_X) * 2
					mov al, RIGHT_DOWN 
					stosw

					mov di, (LEFT_UP_Y * 80 + (LEFT_UP_X + 1) ) * 2
					mov cl, RIGHT_DOWN_X - LEFT_UP_X - 1
					mov al, HOR_LINE								

Horizontal:			stosw
					add di, (RIGHT_DOWN_Y - LEFT_UP_Y) * 160 - 2
					stosw				
					sub di, (RIGHT_DOWN_Y - LEFT_UP_Y) * 160 
					loop Horizontal

					mov di, ((LEFT_UP_Y + 1) * 80 + LEFT_UP_X) * 2
					mov cl, RIGHT_DOWN_Y - LEFT_UP_Y - 1
					mov al, VER_LINE								

Vertical:			stosw
					add di, (RIGHT_DOWN_X - LEFT_UP_X - 1) * 2
					stosw				
					add di, (80 - (RIGHT_DOWN_X - LEFT_UP_X) - 1) * 2 
					loop Vertical
           		
					ret
draw_frame  		endp

;--------------------------------------------------------------------------------------------
; Output the ax register
; Entry: ax - value; es - videseg; di - addres where should to draw
; Assumes: show the ax register in video memory
; Returns: -
;--------------------------------------------------------------------------------------------
show_ax         	proc
					push bx cx dx
 	              	std            									; di decrease; that is, the reverse order

                	mov bx, 16d     

AgainDiv:	      	xor dx, dx
					div bx 		
                	cmp dl, 10d
					jl FirsSym										; dl < 10
					jae SecondSym  									; dl >= 10

Next:           	mov cx, ax      								; save the quotient of division
					mov al, dl
                	mov ah, COLOR_SYMBOL
                	stosw          
                	mov ax, cx      
                	cmp al, 0       
                	jne AgainDiv

                	jmp Done

FirsSym:			add dl, '0'
					jmp Next

SecondSym:			add dl, 'A' - 10
					jmp Next

Done:	    		pop dx cx bx
			     	ret

show_ax            	endp         

;--------------------------------------------------------------------------------------------
; Get address of the place where should to draw
; Entry: dl - y offset
; Assumes: -
; Returns: di - adress of a place
;--------------------------------------------------------------------------------------------
get_address			proc		
					push ax dx

					add dl, LEFT_UP_Y
					mov al, 160
					mul dl
					mov di, ax
					add di, (RIGHT_DOWN_X - 2) * 2

					pop dx ax
					ret 
get_address			endp

;--------------------------------------------------------------------------------------------
; Output the values of all registers to video memory 
; Entry: ax - value
; Assumes: Show all registers in video memory; es - videoseg
; Returns: -
;--------------------------------------------------------------------------------------------
show_regs			proc
					push VIDEO_MEM_ADDRESS
					pop es
					
					std 

					mov cx, COUNT_REGS
					xor bx, bx
					xor dl, dl

Again:				inc dl
					call get_address
					mov ax, regs[bx]
					add bx, 2
					call show_ax	
					loop Again		

; 'reg = '
					cld
					push ax bx di si

					mov bh, 'A'
					mov bl, 'X'
					mov di, ((LEFT_UP_Y + 1) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str

					mov bh, 'B'
					mov bl, 'X'
					mov di, ((LEFT_UP_Y + 2) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str

					mov bh, 'C'
					mov bl, 'X'
					mov di, ((LEFT_UP_Y + 3) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str

					mov bh, 'D'
					mov bl, 'X'
					mov di, ((LEFT_UP_Y + 4) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str

					mov bh, 'S'
					mov bl, 'I'
					mov di, ((LEFT_UP_Y + 5) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str

					mov bh, 'D'
					mov bl, 'I'
					mov di, ((LEFT_UP_Y + 6) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str

					mov bh, 'B'
					mov bl, 'P'
					mov di, ((LEFT_UP_Y + 7) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str

					mov bh, 'S'
					mov bl, 'P'
					mov di, ((LEFT_UP_Y + 8) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str

					mov bh, 'D'
					mov bl, 'S'
					mov di, ((LEFT_UP_Y + 9) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str
					
					mov bh, 'E'
					mov bl, 'S'
					mov di, ((LEFT_UP_Y + 10) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str

					mov bh, 'S'
					mov bl, 'S'
					mov di, ((LEFT_UP_Y + 11) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str

					mov bh, 'C'
					mov bl, 'S'
					mov di, ((LEFT_UP_Y + 12) * 80 + (LEFT_UP_X + 2)) * 2
					call print_str

					pop si di bx ax
					ret
show_regs			endp

;--------------------------------------------------------------------------------------------
; Output a message to video memory
; Entry: bx - message
; Assumes: -
; Returns: str - 'reg' = ...
;--------------------------------------------------------------------------------------------
print_str			proc
					mov ah, COLOR_SYMBOL 

					mov al, bh
                	stosw
					mov al, bl
                	stosw
					mov al, SPACE
                	stosw
					mov al, '='
                	stosw
					
					ret

print_str			endp
					
regs        dw  COUNT_REGS  DUP(?)
copy        dw  ?
to_draw     db  0

EOP:
end Start