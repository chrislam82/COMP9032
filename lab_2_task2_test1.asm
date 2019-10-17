.def pattern1=r16                   ; store pattern1,2,3 in r16,17,18
.def pattern2=r17                   ;
.def pattern3=r18                   ;
.def i=r19                          ; i,j,k stores count for pattern switch delay
.def j=r20
.def k=r21      
 
.include "m2560def.inc"
 
.macro delay                        ; delay state. Checks for button press during delay
    clr i                           ; i,j,k = 0
    clr j
    clr k
loop_i:
    ; run a PB check here, if so, run a continuous loop until PB pressed again. Else, continue
    cpi i, 0xFF            
    breq loop_j
    inc i
    rjmp loop_i
loop_j:
    clr i
    cpi j, 0xFF
    breq loop_k
    inc j
    rjmp loop_i
loop_k:
    clr i
    clr j
    cpi k, 0x40
    breq delay_end
    inc k
    rjmp loop_i
delay_end:
.endmacro
 
    clr r22
    out DDRD,r22                ; PORTD setup for input from PB(Press Button)
    ser r22
    out DDRC, r22               ; PORTC setup for output to LEDs
    ldi r22, 0b10000000
    sbi PIND, 7                 ; init PORTDpin(7) to 1
waiting:
    delay                       ; <= 1sec delay
    sbic PIND, 7                ; if PORTDpin(7)== 0, start pattern . Else, wait/poll
    rjmp waiting
    delay
    sbi PIND, 7
    inc r22
    out PORTC, r22
    rjmp waiting
 
    ; Basically all i need now is to figure out how to get it to go from 1 to 0 using PB0
    ; Once done, everything else should be done