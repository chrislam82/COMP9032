;
; lab_2_task1.asm
;
; Created: 09/10/2019
; Last Modified: 10/10/2019
; Version: 2.1.0
; 
; File: Recursive function to perform gcd using mod
;

.include "m2560def.inc"
.def aL=r16                     ; define aL to be register r16
.def aH=r17                     ; define aH to be register r17
.def bL=r18                     ; define bL to be register r18
.def bH=r19                     ; define bH to be register r19
.def cL=r20                     ; define bL to be register r20
.def cH=r21                     ; define bH to be register r21
.def tempL=r22                  ; define tempL to be register r22
.def tempH=r23                  ; define tempH to be register r23
.equ a=100
.equ b=200

.macro mod                      ; Macro to return n1 (@1:@0) % n2 (@3:@2) in n1
mod_loop:
    cp @0, @2                   ; Compare n1 and n2
    cpc @1, @3                  ;
    brlo mod_end                ; If n1 < n2, then n1 contains the remainder (ret val). jump to mod_end
    sub @0, @2                  ; else, n1 >= n2
    sbc @1, @3                  ; n1 -= n2
    rjmp mod_loop               ; repeat loop
mod_end:
.endmacro
 
main:
    ldi aL, low(a)
    ldi aH, high(a)
    ldi bL, low(b)
    ldi bH, high(b)
    rcall gcd
end:
    rjmp end
 
gcd:                            ; Find gcd of a and b and store result in c
    ; prologue
    push tempL
    push tempH
	push aL
	push aH
	push bL
	push bH
    push YL
    push YH
    in YL, SPL
    in YH, SPH
    sbiw Y,4                    ; allocate space for parameters and local variables
    out SPH, YH
    out SPL, YL
    std Y+1, bL                 ; store parameters a and b in stack frame	; do i need to store temp in stack frame?
    std Y+2, bH
    std Y+3, aL
    std Y+4, aH
    ; main
    cpi bL, 0
    brne gcd_notEqualZero       ; branch to gcd_notEqualZero if bL!=0
    cpi bH, 0
    brne gcd_notEqualZero       ; branch to gcd_notEqualZero if bH!=0
gcd_equalZero:
	movw cH:cL, aH:aL
    rjmp gcd_end                ; else, return c
gcd_notEqualZero:
    mod aL, aH, bL, bH          ; a%b
    movw tempH:tempL, aH:aL     ; store a in temp
    movw aH:aL, bH:bL           ; store b in a
    movw bH:bL, tempH:tempL     ; store temp in b
    rcall gcd
gcd_end:
    ; epilogue
    adiw Y, 4
    out SPH, YH
    out SPL, YL
    pop YH
    pop YL
	pop bH
	pop bL
	pop aH
	pop aL
    pop temp
    pop tempH
    ret
