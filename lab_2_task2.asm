; lab_2_task2.asm
;
; Created: 15/10/2019
; Last Modified: 17/10/2019
; Version: 2.0.0
; 
; File:
;   LED on Arduino to display a sequence of 3 patterns
;   with 0.5sec delay stored in registers before execution.
;   Display halts at current pattern when a button is pressed. 
;	Display resumes when button is pressed again
;	Clock frequency of 16MHz
;
; 		1Mhz = 1mil hertz
; 		1hertz = 1 cycle
; 		Therefore, 1Mhz = 1million cycles/second
; 		16 Mhz = 16million clock cycles/second
;       0.5sec delay = 8million clock cycle
 
.include "m2560def.inc"
 
.def pattern1=r16                   ; store pattern1,2,3 in r16,17,18
.def pattern2=r17                   ;
.def pattern3=r18                   ;
.def i=r19                          ; i,j,k stores count for pattern switch delay
.def j=r20
.def k=r21        
.def a1=r23                         ; a1,2,3 for storing 3 byte integer for comparison
.def a2=r24
.def a3 =r25
.equ delaycount=666666              ; 8000000/12 ~= 666666. Flat cycle of 8 + 8. Loop cost of 12. Total cycle count 8,000,008

.macro delay                        ; delay state. delay pattern switch and check if button pressed
    clr i                           ; loop counters: i,j,k = 0
    clr j
    clr k
	ldi a1,low(delaycount)
	ldi a2,high(delaycount) 
	ldi a3,byte3(delaycount)
	ldi r22,1
	clr r15
check_button:                       ; check if button pressed (PIND(0)==0)
    sbic PIND, 0
    rjmp pause                      ; if not, continue pause
button_pressed:                     ; else, pause the delay by entering pressed
    sbis PIND, 0                    ; check until button released (PIND(0)==0)
    rjmp button_pressed             ; once pressed, exit loop
increment_pause:
	cp i,a1                         ; increment counter (i,j,k)
	cpc j,a2
	cpc k, a3
	breq delay_end                  ; check if delay has reached a counter of delaycount (~= 0.5sec)
	add i, r22
	adc j,r15
	adc k,r15
	rjmp check_button               ; repeat delaying loop
delay_end:
.endmacro
 
main:
    ldi pattern1, 0b10000001        ; load patterns into registers
    ldi pattern2, 0b01011010
    ldi pattern3, 0b00100100
    clr r22                         ; use r22 for port setup
    out DDRD, r22                   ; set PORTD for input from PB0(Press Button)
    ser r22
    out DDRC, r22                   ; set PORTC for output to LEDs
pattern_loop:
    out PORTC, pattern1             ; loop: load pattern[1,2,3] into Port C then enter delay state
    delay
    out PORTC, pattern2
    delay
    out PORTC, pattern3
    delay
    rjmp pattern_loop
end:
    rjmp end