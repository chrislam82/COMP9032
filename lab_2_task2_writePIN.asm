; testing if I can modify PINx I/O reg
    ; can definitely modify PINx when set to output
    ; what about input?
   
 
.include "m2560def.inc"
   
    ser r17             ; set for output
    out DDRC, r17
    clr r17             ; modify pins
    ;out PINC, r17
    ;sbi PINC, 3
    ;sbi PINC, 4
 
    clr r17
    out DDRC, r17       ; set to input
    out PINC, r17       ; modify pins
    sbi PINC, 1
    sbi PINC, 3
    in r18, PINC        ; read from pins
 
    ser r17
    out DDRC, r17       ; setup port C for output to LED
 
load:
    out PORTC, r18 
    rjmp load
