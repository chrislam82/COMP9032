;
; lab_1_task1.asm
;
; Author: Christopher Shu Chun Lam
; zID: z3460499
; Created: 25/09/2019
; Last Modified: 26/09/2019
; Version: 1.1.0
; 
; File: Converts string to decimal form
;		Base of string (hex or dec) determined by MSB (1 for hex, 0 for dec)
;		Assumes valid input (to test, compare with a range of values)
;		Assuming valid input, to test for full range of hex, test register value for value >= 65 ("A" = 65). If true, value in a = a - 65 + 10

.include "m2560def.inc"
.def a=r16 				; define a to be register r16
.def b=r17 				; define b to be register r17
.def base=r18 			; register to store base of string

main:
;	ldi a,183			; Just for testing ("78" in hex) ("7" = 55 in decimal)
;	ldi b,184
	cpi a, 128 			; Compare larger char (a) with 128 (0b1000 0000) to determine MSB. MSB not used by ASCII so MSB determines base of string
	brsh hex 			; if (a >= 0b1000 000), MSB = 1, string base is hex (16)
if_decimal:
		ldi base, 10 	; else, MSB = 0, string base = 10 (decimal)
		rjmp next
else_hex:
		ldi base, 16 	; Since hex, store base of 16 in register (base)
		subi a, 128		; Remove hex flag value (128 = 0b1000 0000) from a since not actually part of value
		subi b, 128		; Remove hex flag value (128 = 0b1000 0000) from b since not actually part of value
next:
	subi a, 48			; Convert data from ASCII to decimal through offset (e.g. 1 in ASCII = 49. 49-48 = 1)
	subi b, 48			; Convert data from ASCII to decimal through offset
	mul a,base 			; multiply larger digit with base to get it's decimal value
	mov a,r0 			; move result back into a
	add a,b 			; a+b to get decimal value of string
halt:
	rjmp halt 			; halt execution


; Can use SWAP (1 clock cycle) to also multiply by 16. Would reduce clock cycle by 2 (mul 2, mov 1)
; Another way to improve performance is to add b,r0 instead of mov into a. This would reduce clock cycle by 1 (result stored in b then)
