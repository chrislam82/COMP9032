.include "m2560def.inc" ; m2560def.inc contains port and register definitions for the ATmega2560 chip
.def a=r16	; define a to be register r16
.def b=r17	; define a to be register r17
.def c=r10	; define a to be register r10

main:	; main is a label
	ldi a, 10	; load value 10 into a	; ldi = load Immediate <-- load 8bit constant to R16-31
	ldi b, -20	; 
	lsl a	; 2*a lsl = logical shift left so shift bits. lsl equal to x2
	add a, b	; 2*a+b
	mov c, a	; c = 2*a+b
halt:
	rjmp halt	; halt the processor execution ; rjump = relative jump so endless loop