; project_PWMtest.asm
; Name: Christopher Shu Chun Lam
; Version: 1.0.0
; Created: 4.11.2019
; Last Modified: 4.11.2019
;
; Goal:
;       1. Test enabling all 4 PWM LEDs (DONE)
;       2. Test PWM changing during runtime (DONE)
;           Port connections defined in comments
;           Everything seems to work
 
.include "m2560def.inc"
.def priorityControl=r16                ; centralControl(0-1), emergency(2)
.def individualControl=r17              ; T5A(0-1), T5B(2-3), T5C(4-5), T4C(6-7)
.def temp0=r23
.def temp1=r24
.def temp2=r25
 
    ; PWM signal strengths picked based on most discernable visual difference
    ; According to specs, the brighter the LEDs, the darker the window
.equ PWMclear=0
.equ PWMlight=8
.equ PWMmedium=32
.equ PWMdark=0xFF
 
.macro enableL
    ldi temp1, 0b_0011_1000                ; Enable Port L bit3,4,5 as output
    sts DDRL, temp1
 
    ldi temp1, high(PWMclear)           ; Load PWM into overflow compare register A (PL4) for Timer5 (PortL)
    sts OCR5AH, temp1
    ldi temp1, low(PWMclear)
    sts OCR5AL, temp1
 
    ldi temp1, high(PWMlight)           ; Load PWM into overflow compare register B (PL3) for Timer5
    sts OCR5BH, temp1
    ldi temp1, low(PWMlight)
    sts OCR5BL, temp1
 
    ldi temp1, high(PWMmedium)          ; Load PWM into overflow compare register C (PL2) for Timer5
    sts OCR5CH, temp1
    ldi temp1, low(PWMmedium)
    sts OCR5CL, temp1
 
    ldi temp1, (1<<CS50)                 ; CS --> Clock Selection (Prescalers to clock timer). CSx0 is just standard with no prescaling
    sts TCCR5B, temp1
    ldi temp1, (1<<WGM50)|(1<<COM5A1)|(1<<COM5B1)|(1<<COM5C1)    ; WGM --> Waveform Generation Mode (I.e. Phase Correct, Fast PWM).  --> WGMx0 is phase correct count from 0 to  0xFF
    sts TCCR5A, temp1                   ; COM --> Compare output mode (What happens when compare --> COMxA1 Clear when match counting up, set when compare counting down)
.endmacro
 
.macro enableH
    ldi temp1, 0b_0010_0000                ; Enable Port H bit5 as output
    sts DDRH, temp1
 
    ldi temp1, high(PWMdark)            ; Load PWM into overflow compare register C (PH8) for Timer4 (PortH)
    sts OCR4CH, temp1
    ldi temp1, low(PWMdark)
    sts OCR4CL, temp1
 
    ldi temp1, (1<<CS40)                 ; CS --> Clock Selection (Prescalers to clock timer). CSx0 is just standard with no prescaling
    sts TCCR4B, temp1
    ldi temp1, (1<<WGM40)|(1<<COM4C1)    ; WGM --> Waveform Generation Mode (I.e. Phase Correct, Fast PWM).  --> WGMx0 is phase correct count from 0 to  0xFF
    sts TCCR4A, temp1                   ; COM --> Compare output mode (What happens when compare --> COMxA1 Clear when match counting up, set when compare counting down)
.endmacro
 
.macro loadState    ; Load @2 into @1:@0 (I/O Address)
    ldi temp1, high(@2)
    sts @1, temp1
    ldi temp1, low(@2)
    sts @0, temp1
.endmacro
 
.macro incState                 ; Seems to be working now. While compare register is 2 byte, we only comparing up to 0xFF, hence no need to compare with/change High register
    lds temp1, @0
    cpi temp1, PWMdark
    breq incDark
    cpi temp1, PWMmedium
    breq incMedium
incLight:
    ldi temp1, PWMclear
    rjmp incEnd
incMedium:
    ldi temp1, PWMlight
    rjmp incEnd
incDark:
    ldi temp1, PWMmedium
incEnd:
    sts @0, temp1
.endmacro
 
.macro decState                 ; Same thing but reversed direction
    lds temp1, @0
    cpi temp1, PWMclear
    breq decClear
    cpi temp1, PWMlight
    breq decLight
decMedium:
    ldi temp1, PWMdark
    rjmp decEnd
decLight:
    ldi temp1, PWMmedium
    rjmp decEnd
decClear:
    ldi temp1, PWMlight
decEnd:
    sts @0, temp1
.endmacro
 
main: 					; Testing decreasing brightness, then increasing again.
    enableL
    enableH
 
    ldi temp2, 250
    rcall delay
    ldi temp2, 250
    rcall delay
    incState OCR4CL
 
    ldi temp2, 250
    rcall delay
    ldi temp2, 250
    rcall delay
    incState OCR4CL
 
    ldi temp2, 250
    rcall delay
    ldi temp2, 250
    rcall delay
    incState OCR4CL
 
    ldi temp2, 250
    rcall delay
    ldi temp2, 250
    rcall delay
    decState OCR4CL
 
    ldi temp2, 250
    rcall delay
    ldi temp2, 250
    rcall delay
    decState OCR4CL
 
    ldi temp2, 250
    rcall delay
    ldi temp2, 250
    rcall delay
    decState OCR4CL
end:
    rjmp end
 
.equ CPUfreq = 16_000_000
.equ msDelay = CPUfreq / 4 / 1_000
 
delay_1ms:
    push temp2
    push temp1
    ldi temp2, high(msDelay)
    ldi temp1, low(msDelay)
delay_1msLoop:
    sbiw temp2:temp1, 1
    brne delay_1msLoop
    pop temp1
    pop temp2
    ret
 
delay:
    rcall delay_1ms
    subi temp2, 1
    brne delay
    ret