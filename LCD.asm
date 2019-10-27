
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CODE 2 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Test code from Hui Wu
; Board settings: 1. Connect LCD data pins D0-D7 to PORTF0-7.
; 2. Connect the four LCD control pins BE-RS to PORTA4-7.
  
.include "m2560def.inc"

.macro do_lcd_command 						; write a command to LCD instruction memory
	ldi temp1, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data 							; write data to LCD data memory
	ldi temp1, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

;.org 0
;	jmp RESET

;;;;;;;;; LCD INIT

RESET:										; stack pointer to RAMEND? WHY? is it necessary?
	ldi temp1, low(RAMEND)
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1

	ser temp1
	out DDRE, temp1
	out DDRA, temp1
	clr temp1
	out PORTE, temp1
	out PORTA, temp1

	do_lcd_command 0b00111000 				; 2x5x7
	ldi temp2, high(5)						; delay for 5ms
	ldi temp1, low(5)
	rcall delay
	do_lcd_command 0b00111000 				; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 				; 2x5x7
	do_lcd_command 0b00111000 				; 2x5x7
	do_lcd_command 0b00001000 				; display off
	do_lcd_command 0b00000001 				; clear display
	do_lcd_command 0b00000110 				; increment, no display shift
	do_lcd_command 0b00001110 				; Cursor on, bar, no blink

	do_lcd_data 'H'
	do_lcd_data 'e'
	do_lcd_data 'l'
	do_lcd_data 'l'
	do_lcd_data 'o'
	do_lcd_data '1'
	do_lcd_data '2'
	do_lcd_data '3'

halt:
	rjmp halt

;;;;;;;;;;; LCD SETUP STUFF

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4
.equ LCD_BF = 7

.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clr
	cbi PORTA, @0
.endmacro

;
; Send a command to the LCD (temp1)
;

lcd_command:
	out PORTE, temp1
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	ret

lcd_data:
	out PORTE, temp1
	lcd_set LCD_RS 				; Set LCD to read
	nop
	nop
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	lcd_clr LCD_RS 				; set back to write
	ret

;;;;;;;;;; Function call. Check BF until LCD ready

lcd_wait:						; function call. check busy flag until LCD ready
	push temp1
	clr temp1
	out DDRE, temp1 			; make portF input port
	out PORTE, temp1			; activate pullup
	lcd_set LCD_RW 				; set to read(1) from LCD
lcd_wait_loop:
	nop
	lcd_set LCD_E 				; turn on enable pin
	nop
	nop
    nop
	in temp1, PINE 				; read from pinF and see if BF is set(busy)
	lcd_clr LCD_E
	sbrc temp1, LCD_BF 			; keep checking until no longer busy
	rjmp lcd_wait_loop
	lcd_clr LCD_RW 				; Set LCD back to write(0)
	ser temp1
	out DDRE, temp1 				; set portF back to output port
	pop temp1 					; end function call
	ret

;;;;;;;;;; 1 MS delay function calls

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:						; close enough to 1ms
	push temp1 					; 4 cycless
	push temp2
	ldi temp2, high(DELAY_1MS)	; 2 cycles
	ldi temp1, low(DELAY_1MS)
delayloop_1ms:
	sbiw temp2:temp1, 1 		; 4 standard. 3 last
	brne delayloop_1ms
	pop temp2 					; 4 cycles
	pop temp1
	ret 						; 4 cycles

delay:
	rcall sleep_1ms
	sbiw temp2:temp1, 1
	brne delayLoop
	ret
