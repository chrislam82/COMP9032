;
; Lab 2_2.asm
;
; Created: 2019/10/17
; Author : Qingsong Sun
; Version 3
;
.include "m2560def.inc"

;16MHz = 16 000 000 Hz /s
;8 000 000 /0.5s
.equ loop_count = 12499 ; (100 000 - 4 - 4) / 8 = 12499
.equ loop_count2 = 80 ; 8 000 000 / 100 000 = 80

.equ pattern1 = 0xAA
.equ pattern2 = 0xF0
.equ pattern3 = 0x0F

.def output = r19
.def temp = r20
.def count2 = r18
.def flag = r21				; if flag = 1, stop;	if flag = 0, continue

.def iH = r25
.def iL = r24
.def countH = r17
.def countL = r16

; reference: week3_notes2 page28 example2
.macro sdelay; 100 000/one time (need 80 times)
	ldi countL, low(loop_count) ; 1 cycle
	ldi countH, high(loop_count)
	clr iH ; 1
	clr iL
loop: 
	cp iL, countL				; 1
	cpc iH, countH
	brsh done					; 1, 2 (if branch)
	adiw iH:iL, 1				; 2
	nop
	rjmp loop					; 2
done:
.endmacro

.macro HalfSecondDelay ; 80 * 100 000 = 8 000 000
	ldi count2, 0
loop2:
	inc count2
	sdelay 
	cpi count2, loop_count2
	brne loop2
done2:
.endmacro


; reference: week4_notes2 page43 example1
	jmp RESET

.org INT0addr ; defined in m2560def.inc
	jmp EXT_INT0


RESET:
	clr flag ; flag = 0 in the start
	ser output
	out DDRC, output ; set Port C for output

	ldi temp, (2 << ISC00) ; set INT0 as falling edge triggered interrupt
	sts EICRA, temp; Store Direct to data space

	in temp, EIMSK ; enable INT0
	ori temp, (1<<INT0) ;  Logical OR with Immediate
	out EIMSK, temp

	sei ; enable Global Interrupt
	jmp main


EXT_INT0:
	cpi flag, 0  ; if flag = 0 , jump into stop
	breq stop
	
	ldi flag, 0  ; flag = 0
	rjmp return

stop:
	ldi flag, 1  ; flag = 1
	
return:	
	reti ; Interrupt Return



main:
	clr temp

loop_3patterns:

check_stop:
	cpi flag, 1			; if flag = 1, jump to stop_loop
	breq stop_loop
	rjmp first			; if flag = 0, jump to next
stop_loop:
	rjmp check_stop

first:
	ldi output, pattern1 ; write the pattern 1: 1010 1010
	out PORTC, output
	HalfSecondDelay



check_stop2:
	cpi flag, 1
	breq stop_loop2
	rjmp second
stop_loop2:
	rjmp check_stop2

second:
	ldi output, pattern2 ; write the pattern 2: 1111 0000
	out PORTC, output
	HalfSecondDelay


check_stop3:
	cpi flag, 1
	breq stop_loop3
	rjmp third
stop_loop3:
	rjmp check_stop3

third:
	ldi output, pattern3 ; write the pattern 3: 0000 1111
	out PORTC, output
	HalfSecondDelay

	rjmp loop_3patterns

end:
	rjmp end
	