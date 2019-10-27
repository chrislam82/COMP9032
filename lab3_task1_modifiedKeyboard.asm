;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CODE 2 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test code from Hui Wu
; Modified for alternate port (C)
 
; LCD Data finally works with PortC
    ; D0-3 to PC7-4
    ; D4-7 to PC3-0
; LCD CTRL as usual to PortA
    ; Connect the four LCD control pins BE-RS to PORTA4-7.
; LED to any of A/B/G (just use 4 pins)
    ; any 4 leds is fine. Just use G since close
; Keypad to PortF
    ; Port F is used for keypad, high 4 bits for column selection, low four bits for reading rows. On the board, RF7-4 connect to C3-0, RF3-0 connect to R3-0.
 
    ; PortC/F seem working (Be careful of labelling order)
    ; Port A/B/G i can use but only ~4pins

    ; PortD seems only partially working (Only pin 0-3 work)
    ; PortE is scrambled. unusable. Only a 3 pins work and not next to each other either
        ; Only use D/E for single pins
 
.include "m2560def.inc"
 
.macro do_lcd_command
    ldi r16, @0
    rcall lcd_command
    rcall lcd_wait
.endmacro
.macro do_lcd_data
    ldi r16, @0
    rcall lcd_data
    rcall lcd_wait
.endmacro
 
;.org 0
;   jmp RESET
 
 
RESET:
    ldi r16, low(RAMEND)
    out SPL, r16
    ldi r16, high(RAMEND)
    out SPH, r16
 
    ser r16
    out DDRC, r16
    out DDRA, r16
    clr r16
    out PORTC, r16
    out PORTA, r16
 
    do_lcd_command 0b00111000 ; 2x5x7
    rcall sleep_5ms
    do_lcd_command 0b00111000 ; 2x5x7
    rcall sleep_1ms
    do_lcd_command 0b00111000 ; 2x5x7
    do_lcd_command 0b00111000 ; 2x5x7
    do_lcd_command 0b00001000 ; display off
    do_lcd_command 0b00000001 ; clear display
    do_lcd_command 0b00000110 ; increment, no display shift
    do_lcd_command 0b00001110 ; Cursor on, bar, no blink
 
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
 
halt:
    rjmp halt
 
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4
 
.macro lcd_set
    sbi PORTA, @0
.endmacro
.macro lcd_clr
    cbi PORTA, @0
.endmacro
 
;
; Send a command to the LCD (r16)
;
 
lcd_command:
    out PORTC, r16
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
    out PORTC, r16
    lcd_set LCD_RS
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
    lcd_clr LCD_RS
    ret
 
lcd_wait:
    push r16
    clr r16
    out DDRC, r16
    out PORTC, r16
    lcd_set LCD_RW
lcd_wait_loop:
    nop
    lcd_set LCD_E
    nop
    nop
        nop
    in r16, PINC
    lcd_clr LCD_E
    sbrc r16, 7
    rjmp lcd_wait_loop
    lcd_clr LCD_RW
    ser r16
    out DDRC, r16
    pop r16
    ret
 
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead
 
sleep_1ms:
    push r24
    push r25
    ldi r25, high(DELAY_1MS)
    ldi r24, low(DELAY_1MS)
delayloop_1ms:
    sbiw r25:r24, 1
    brne delayloop_1ms
    pop r25
    pop r24
    ret
 
sleep_5ms:
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    ret