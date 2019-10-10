;
; lab_1_task2.asm
;
; Author: Christopher Shu Chun Lam, Qingsong Sun
; zID: z3460499, z5222508
; Created: 26/09/2019
; Last Modified: 03/10/2019
; Version: 3.0.0
; 
; File: Converts code from c into AVR
;		Performs GCD to find GCD between 2 positive integers using subtraction method
; 

.include "m2560def.inc"
.def aL=r16 					; define aL to be register r16
.def aH=r17 					; define aH to be register r17
.def bL=r18 					; define bL to be register r18
.def bH=r19 					; define aH to be register r19
.equ a=1000
.equ b=1100

main:
	ldi aL, low(a)
	ldi aH, high(a)
	ldi bL, low(b)
	ldi bH, high(b)
loop:
	cp aL,bL 					; compare a,b
	cpc aH,bH
	breq terminate 				; terminate if a=b
	brsh else_aGreaterb			; if a<b, don't jump. Else a>b, jump to else_aGreaterb
if_aLessb:
	sub bL,aL					; b = b - a 
	sbc bH,aH
	rjmp loop					; repeat loop
else_aGreaterb:
	sub	aL,bL					; a = a - b
	sbc	aH,bH
	rjmp loop					; repeat loop
terminate:
	rjmp terminate				; endless loop