; lab3_task1.asm

; So how to implement?
; Other instructions are mainly decorative. Writing to LCD. Basically, just fill in at the end. the rest is just keypad
; Main thing is just reading input from keypad and doing branching based on input

; What happens when a,b or c overflow?
	; I assume it is invalid since they are meant to be 0
	; Hence, I would reset back to start
	; Overflow: check if r1 is 0, else, there is overflow into a 2 byte integer (which does not match specs and is therefore invalid)
		; If so, flash LEDs then jump to main to restart

.define row = r16						; Store current row/column being checked
.define col = r17
.define rMask = r18						; Row/column masks
.define cMask = r19
.define temp1 = r20
.define temp2 = r21
.define result = r22					; Stores result = b x c
.define second = r23					; 0 indicates currently writing b. 1 indicates currently writing c
.define b = r23	
.define c = r24

.equ portFDir = 0x0F					; Set pin7-4 output/pin3-0 input
.equ rowMask = 0x0F						; So that we only check input from pin3-0
.equ initColMask = 0xEF					; Only 1st col set to 0
	; 0b 1110 1111
	; set pins to 0 starting from pin4 (to 7)
.equ initRowMask = 0x01					; Only 1st row set to 1 (for logical AND)
	; scan pins starting from pin0 (to 3)

.include "m2560def.inc"

.macro writeNumber						; Macro for writing number to register @0
	ldi temp1, 10						; Shift all decimal digits to the right
	mul @0, temp1 						; by multiplying @0 by 10 and moving back to @0
	mov r0, @0
	cpi row, 3							; if 3rd row, num is 0
	breq writeNumberEnd 				; If so, end macro since nothing to be added
	mov temp1, row 						; Else, store number pressed to temp1
	lsl temp1 							; new single digit (temp1) = 1 + 3row + col
	add temp1, row
	add temp1,col
	subi temp1, -1
	add @0, temp1						; Add this digit to the register @0
writeNumberEnd:
.endmacro

RESET:
	ldi temp1, portFDir					; Setup keypad for output(pin7-4)/input(pin3-0) from portF
	out DDRF, temp1

main:
	clr b 								; reset b,c and result for start of a calculation
	clr c
	clr result
resetMasks:
	ldi cMask, initColMask				; Set column mask to init mask
	clr col
colLoop:
	cpi col, 3							; Scan 3 columns of keypad (4th not used)
	breq main 
	out PORTF, cMask 					; Column mask. Determines which column set to 0
		ldi temp1, 0xFF					; add ~= 32ms delay (~=256x2/16mil sec)
tempDelay:								; to reduce chance of registering a key press multiple times
		dec temp1
		brne tempDelay
	in temp1, PINF						; Read portF pins
	andi temp1, rowMask					; Use logical AND to check if any rows (pin3-0) set to 0
	cpi temp1, 0xF
	breq nextCol 						; If not, jump to nextCol
	ldi rMask, initRowMask				; Else, prepare for row scan
	clr row 							; load initial row mask and row number
rowLoop:
	cpi row, 4							; Once all 4 rows scanned, move to next column
	breq nextCol
		; temp1 contains pins in register
		; we could remove temp2 if we read from pins each row loop (hence no need to store) then
		; Try without later. I dont think its necessary other than maybe timing of execution
	mov temp2, temp1
	and temp2, rMask 					; logical AND with row mask to check if a particular row set
	breq execution 						; found a set row. Execute and do something
	inc row 							; else, continue to next row
	lsl rMask 							; by lsl row mask
	jmp rowLoop 						; and repeat the loop
nextCol:
	lsl cMask 							; Prepare for next column by lsl column mask
	inc col 							; lsl 0b1110 1111 --> 
	jmp colLoop

execution: 								; Found a button pressed somewhere
	cpi row,3							; we have an operand or 0
	breq operand
a: 										; else input was a number
	cpi second, 1						; check if we are imputting to b (second == 1)
	breq b 								; if not, call macro to add digit to a
	writeNumber a
	rjmp resetMasks						; Then start scanning again from the start (top-left)
b:	 									; (second == 1), so currently writing to b
	writeNumber b 						; Call macro to add new digit to b
	rjmp resetMasks						; Then start scanning again from the start (top-left)
operand:
	cpi col, 1							; Check if input was 0 (col 1)
	breq a 								; If so, write to a or b depending on second
	cpi col, 2							; Check if button was # (compute result)
	breq multiply
multiply: 								; If not, button was * (multiply)
	ldi second, 1 						; set second to 1 to indicate writing to second integer
	rjmp resetMasks						; Then start scanning again from the start (top-left)
compute: 								; Button pressed was #
	mul b,c 							; Compute (#) the result
	mov result, r0
	rjmp main 							; jump to main and reset everything all fields

; Basically now, finish LCD lecture
; Go through sample code
; Implement LCD showing result
; test

; LED should be done last. Just a flash if r1 written to during mul indicating overflow