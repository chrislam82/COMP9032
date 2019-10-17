; example4
; activate pattern if button pressed successfully
 
.include "m2560def.inc"
   
    cbi DDRD,7          ; setup pin7 for input
    ser r17
    out DDRC, r17       ; setup port C for output to LED
    sbi PIND, 7         ; set bit to set in case 0 is already loaded
waiting:
    sbic PIND, 7
    rjmp waiting
    ldi r17, 0b10100000
    out PORTC, r17
    rjmp waiting
 
; pins dont default to 0x00. necessary to set bits first then?
    ; PINA empty
    ; PINB 0b 1000 1111
        ; I/O in data memory. More volatile. What happens during setup for execution?