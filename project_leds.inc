; Fix comments and test but everything should be done


; leds.inc
;
; Name:
; zID: 
; Created: 04.11.2019
; Last Modified: 08.11.2019
; Version: 2.1.0
;
; File: Include file storing all LED related assembly code
;		- Initialise using macro init_LEDs
;		- Use "LED options" in main .asm file
;
; Wiring
;	PortH
;		PH8 (pin5) --> LED0, LED1 --> Timer4CompareRegC --> Window1
;	PORTL
;		PL2 (pin5) --> LED2, LED3 --> Timer5CompareRegC --> Window2
;		PL3 (pin4) --> LED4, LED5 --> Timer5CompareRegB --> Window3
;		PL4 (pin3) --> LED6, LED7 --> Timer5CompareRegA --> Window4

; PWM signal strengths picked based on most discernable visual difference
; According to specifications, the brighter the LEDs, the darker the window
.equ PWMclear=0								; level0: this is darkest LED (off)
.equ PWMlight=8								; level1
.equ PWMmedium=32							; level2
.equ PWMdark=0xFF							; level3: this is brightest LED

;;;;;;;;;; Macro. LED initialisation ;;;;;;;;;;
.macro init_LEDs
    ldi temp1, 0b_0011_1000					; Enable Port L bit3,4,5 as output
    sts DDRL, temp1
    ldi temp1, 0b_0010_0000					; Enable Port H bit5 as output
    sts DDRH, temp1

	; Set all windows to clear (level 0) in Initial State (S:)
	ldi temp1, PWMclear
    sts OCR5AH, temp1        
    sts OCR5AL, temp1
    sts OCR5BH, temp1
    sts OCR5BL, temp1
    sts OCR5CH, temp1
    sts OCR5CL, temp1
	sts OCR4CH, temp1
    sts OCR4CL, temp1

	; <------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ Comments. Fix code here and the one down below
    ldi temp1, (1<<CS50)                 ; CS --> Clock Selection (Prescalers to clock timer). CSx0 is just standard with no prescaling
    sts TCCR5B, temp1
    ldi temp1, (1<<CS40)                 ; CS --> Clock Selection (Prescalers to clock timer). CSx0 is just standard with no prescaling
    sts TCCR4B, temp1

    ldi temp1, (1<<WGM50)|(1<<COM5A1)|(1<<COM5B1)|(1<<COM5C1)    ; WGM --> Waveform Generation Mode (I.e. Phase Correct, Fast PWM).  --> WGMx0 is phase correct count from 0 to  0xFF
    sts TCCR5A, temp1					; COM --> Compare output mode (What happens when compare --> COMxA1 Clear when match counting up, set when compare counting down)
    ldi temp1, (1<<WGM40)|(1<<COM4C1)    ; WGM --> Waveform Generation Mode (I.e. Phase Correct, Fast PWM).  --> WGMx0 is phase correct count from 0 to  0xFF
    sts TCCR4A, temp1					; COM --> Compare output mode (What happens when compare --> COMxA1 Clear when match counting up, set when compare counting down)
.endmacro

;;;;;;;;;; Macros. LED options ;;;;;;;;;;
; Options for inc/dec opaqueness state/levels for window 1-4

; Increase state/levels for window 1-4
.macro inc_Win1_led
	incState OCR4CL
.endmacro

.macro inc_Win2_led
	incState OCR5CL
.endmacro

.macro inc_Win3_led
	incState OCR5BL
.endmacro

.macro inc_Win4_led
	incState OCR5AL
.endmacro

; Decrease state/levels for window 1-4
.macro dec_Win1_led
	decState OCR4CL
.endmacro

.macro dec_Win2_led
	decState OCR5CL
.endmacro

.macro dec_Win3_led
	decState OCR5BL
.endmacro

.macro dec_Win4_led
	decState OCR5AL
.endmacro

;;;;;;;;;; Macros. Inc/Dec LED(window) opaqueness state/levels ;;;;;;;;;;
; While compare register is 2 byte, we only comparing up to 0xFF, hence no need to compare with/change High byte register			<========== Fix comment. Especially which mode is only up to 0xFF
.macro incState
	lds temp1, @0				; load current opaqueness level @0 for a given window
	cpi temp1, PWMclear			; Compare and branch to current level
	breq incClear
	cpi temp1, PWMlight
	breq incLight
incMediumDark:					; For each state, increase it's state to the next level and load in temp1
	ldi temp1, PWMdark			; Since PWMdark highest state, PWMdark loads itself
	rjmp incEnd
incLight:
	ldi temp1, PWMmedium
	rjmp incEnd
incClear:
	ldi temp1, PWMlight
incEnd:
	sts @0, temp1				; Store new state to @0 to adjust to new state/level	
.endmacro

.macro decState					; Same logic in macro as incState but shifts
	lds temp1, @0				; opaqueness state/levels in the opposite direction
	cpi temp1, PWMdark
	breq decDark
	cpi temp1, PWMmedium
	breq decMedium
decLightClear:
	ldi temp1, PWMclear
	rjmp decEnd
decMedium:
	ldi temp1, PWMlight
	rjmp decEnd
decDark:
	ldi temp1, PWMmedium
decEnd:
	sts @0, temp1
.endmacro