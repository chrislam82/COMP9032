; lab_4.asm
;
; Name: Christopher Lam
; Created: 12.11.2019
; Last modified: 12.11.2019
; Version: 1.3.1
;
; File:
;		Loads measured rps to LCD screen and is updated every 1 second
;
; Wiring:
;		+5V to Motor(OpE)
;		Motor(OpO) to PortD(RDX4)
;		Input(POT) to Motor(Mot)
;       PortA for LCD_CTRL
;           BE-RS to PORTA4-7
;       PORTC for LCD_DATA
;           D0-3 to PC7-4
;           D4-7 to PC3-0

.include "m2560def.inc"

.def temp0=r19
.def temp1=r20
.def temp2=r21
.def temp3=r22
.def pinCount=r23
.def rpsL=r24
.def rpsH=r25

;;;;;;;;; LCD setup ;;;;;;;;; 
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BF = 7

; LCD instruction to set LCD DD RAM address to start
.equ LCD_start = 0b_1000_0000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Macros ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Reference COMP9032 Week 6 Sample Code
.macro do_lcd_command                   ; write a command to LCD instruction memory
    ldi temp1, @0
    rcall lcd_command
    rcall lcd_wait
.endmacro
 
.macro do_lcd_data                      ; write data to LCD data memory from register being passed in
    ldi temp1, @0
    rcall lcd_data
    rcall lcd_wait
.endmacro

.macro do_lcd_data_reg                      ; write data to LCD data memory from register being passed in
    mov temp1, @0
    rcall lcd_data
    rcall lcd_wait
.endmacro
 
.macro lcd_set
    sbi PORTA, @0
.endmacro
 
.macro lcd_clr
    cbi PORTA, @0
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; IVT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt addresses from m2560def.inc
.cseg 
.org 0x0000
	jmp RESET
.org INT0addr
	jmp holeInterrupt
.org INT1addr
	jmp displayRPS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Interrupts ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RESET:
	; Initialise LCD
	; Reference COMP9032 Week 6 Sample Code
    ser temp1
    out DDRC, temp1                     ; Setup portC for LCD data (output)
    out DDRA, temp1                     ; Setup portA for controlling LCD
    clr temp1
    out PORTC, temp1                    ; Clear ports
    out PORTA, temp1
 
    do_lcd_command 0b00111000           ; 2x5x7
    ldi temp2, 5                        ; delay for 5ms
    rcall delay
    do_lcd_command 0b00111000           ; 2x5x7
    rcall sleep_1ms
    do_lcd_command 0b00111000           ; 2x5x7
    do_lcd_command 0b00111000           ; 2x5x7
    do_lcd_command 0b00001000           ; display off
    do_lcd_command 0b00000001           ; clear display
    do_lcd_command 0b00000110           ; increment, no display shift
    do_lcd_command 0b00001110           ; Cursor on, bar, no blink

	; Enable INT0 and INT1 with falling edge
	ldi temp1, (2<<ISC00) | (2<<ISC10)
	sts EICRA, temp1
	ldi temp1, (1<<INT0) | (1<<INT1)
	out EIMSK, temp1

	ldi temp1, 0b_0000_0010				; Set PortD pin1 (INT1) as intput and default value 1 for software interrupt
	out DDRD, temp1	
	out PORTD, temp1

	clr pinCount						; Clear rps and pin count before entering main
	clr rpsL
	clr rpsH

	sei
	jmp main

; Interrupt counts every hole passed. 4 holes = 1 revolution
holeInterrupt:
	push temp0
	in temp0, SREG
	push temp0
	subi pinCount, -1				; add 1 to number of holes passed
holeInterrupt_loop:
	cpi pinCount, 4					; if number of holes passed currently >= 4,
	brlo holeInterrupt_end
	subi pinCount, 4				; pinCount -= 4 (One revolution)
	adiw rpsH:rpsL, 1				; rps += 1
	rjmp holeInterrupt_loop
holeInterrupt_end:					; Once pinCount < 3, interrupt is finished
	pop temp0
	out SREG, temp0
	pop temp0
	reti

; Assuming an rps < 10,000 given motor provided (max 4digit rps)
;		Use temp2, temp3 to compare value (current digit space value 10s, 100s, ...)
;		Use temp0 to store current digit
displayRPS:
	do_lcd_command LCD_start				; Set LCD address to start of LCD first
	ldi temp2, low(1000)					; Initialise with 1000 and use to check the digit in the 1000s spot
	ldi temp3, high(1000)
	clr temp0
displayRPS_loop:							; For every digit space
	cp rpsL, temp2							; subtract digit space value from rps count
	cpc rpsH, temp3							; until digit space value > rps count
	brlo displayRPS_display					; storing the number of subtractions in temp0
	sub rpsL, temp2
	sbc rpsH, temp3
	inc temp0
	rjmp displayRPS_loop
displayRPS_display:							; write temp0 (digit) to lcd
	subi temp0, -'0'
	do_lcd_data_reg temp0
displayRPS_increment:						; based on set binary digits of digit base (temp3:temp2)
	sbrc temp3, 0							; jump to the corresponding label
	rjmp displayRPS_thousand
	sbrc temp2, 6
	rjmp displayRPS_hundred
	sbrc temp2, 3
	rjmp displayRPS_ten
	rjmp displayRPS_one
displayRPS_thousand:						; if digit base = 1000, load now with 100
	ldi temp2, low(100)
	ldi temp3, high(100)
	clr temp0								; and reset digit count
	rjmp displayRPS_loop
displayRPS_hundred:							; do the same for 100 to 10
	ldi temp2, low(10)
	ldi temp3, high(10)
	clr temp0
	rjmp displayRPS_loop
displayRPS_ten:								; 10 to 1
	ldi temp2, low(1)
	ldi temp3, high(1)
	clr temp0
	rjmp displayRPS_loop
displayRPS_one:								; finally, after writing single digit
	clr pinCount							; all counts are reset
	sbi PORTD, 1							; and prepare PortD bit1 (INT1) for another interurpt
	reti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; MAIN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

main:
	rcall delay1s							; Call a 1 second delay
	cbi PORTD, 1							; Then software enable interrupt for writing counted rps to lcd
	rjmp main

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; END OF MAIN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 
;;;;;;;;;; Function call. Send Instruction/Data to LCD ;;;;;;;;;;
; Reference COMP9032 Week 6 Sample Code
lcd_command:
    out PORTC, temp1
    nop
    lcd_set LCD_E
    nop
    nop
    nop
    lcd_clr LCD_E
    nop
    nop
    nop
    ret
 
lcd_data:
    out PORTC, temp1
    lcd_set LCD_RS                      ; Set LCD to data register
    nop
    nop
    nop
    lcd_set LCD_E
    nop
    nop
    nop
    lcd_clr LCD_E
    nop
    nop
    nop
    lcd_clr LCD_RS                      ; set back to instruction register
    ret
 
;;;;;;;;;; Function call. Check BF until LCD ready ;;;;;;;;;;
 
lcd_wait:                               ; function call. check busy flag until LCD ready
    push temp1
    clr temp1
    out DDRC, temp1                     ; make portC input port
    out PORTC, temp1                    ; activate pullup
    lcd_set LCD_RW                      ; set to read(1) from LCD
lcd_wait_loop:
    nop
    lcd_set LCD_E                       ; turn on enable pin
    nop
    nop
    nop
    in temp1, PINC                      ; read from pinC and see if BF is set(busy)
    lcd_clr LCD_E
    sbrc temp1, LCD_BF                  ; keep checking until no longer busy
    rjmp lcd_wait_loop
    lcd_clr LCD_RW                      ; Set LCD back to write(0)
    ser temp1
    out DDRC, temp1                     ; set portF back to output port
    pop temp1                           ; end function call
    ret

;;;;;;;;;; Delay Function Calls ;;;;;;;;;;
 
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead
 
sleep_1ms:                              ; close enough to 1ms
    push temp1                          ; 4 cycless
    push temp2
    ldi temp2, high(DELAY_1MS)          ; 2 cycles
    ldi temp1, low(DELAY_1MS)
delayloop_1ms:
	subi temp1, 1
	sbci temp2, 0
    brne delayloop_1ms
    pop temp2                           ; 4 cycles
    pop temp1
    ret                                 ; 4 cycles

delay:	
    rcall sleep_1ms
    subi temp2, 1
    brne delay
    ret

; Function call for a 1 second delay
	; Use 2 bytes to store count to 1000 (1000 calls of sleep_1ms)
.equ secondL=low(1000)
.equ secondH=high(1000)
delay1s:
	push temp1
	push temp2
	ldi temp1, secondL
	ldi temp2, secondH
delay1s_loop:
	rcall sleep_1ms
	subi temp1, 1
	sbci temp2, 0
	brne delay1s_loop
	pop temp1
	pop temp2
	ret