; project_LCDtest.asm
; Version: 1.10.0
; Created: 05.11.2019
; Last Modified: 05.11.2019
;		PortA for LCD_CTRL
;			BE-RS to PORTA4-7
; 		PORTC for LCD_DATA
; 			D0-3 to PC7-4
; 			D4-7 to PC3-0

.def temp1=r24
.def temp2=r25
 
.include "m2560def.inc"

;;;;;;;;; LCD setup ;;;;;;;;;
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BF = 7
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; MACROS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.macro do_lcd_command                   ; write a command to LCD instruction memory
    ldi temp1, @0
    rcall lcd_command
    rcall lcd_wait
.endmacro
 
.macro do_lcd_data                      ; write data to LCD data memory from register being passed in
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RESET ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;; LCD_INIT 
RESET:
    ldi temp1, low(RAMEND)              ; To setup the stack
    out SPL, temp1
    ldi temp1, high(RAMEND)             ; But should be setup automatically in ATmega2560
    out SPH, temp1
 
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
 
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; START MAIN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 
 
;;;;;;;;; Main/resetMasks ;;;;;;;;;;
main:
	do_lcd_data 'H'
	do_lcd_data 'e'
	do_lcd_data 'l'
	do_lcd_data 'l'
	do_lcd_data 'o'	
	do_lcd_data ' '
	do_lcd_data 'W'
	do_lcd_data 'o'
	do_lcd_data 'r'
	do_lcd_data 'l'
	do_lcd_data 'd'
	do_lcd_data '!'
	do_lcd_command 0b10000100
end:
	rjmp end
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 
;;;;;;;;;; Function call. Send Instruction/Data to LCD ;;;;;;;;;;
 
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
    sbiw temp2:temp1, 1                 ; 4 standard. 3 last
    brne delayloop_1ms
    pop temp2                           ; 4 cycles
    pop temp1
    ret                                 ; 4 cycles
 
delay:
    rcall sleep_1ms
    subi temp2, 1
    brne delay
    ret
