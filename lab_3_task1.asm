; lab_3_task1.asm
; version: 3.1.0
; Created: 24.10.2019
; Last Modified: 27.10.2019
    ; Everything working clunkily
;Additional Features
    ; Better commenting, fix formatting
    ; If possible, implement button pressing wait. Similar to bouncing, double check that button released before allowing a second insertion
        ; Improves usability
    ; Implement looping calculator if bothered (So don't have to RESET interrupt)
 
; LCD CTRL --> A
; LCD DATA --> C
; LED      --> G
; KEYPAD   --> F
 
; LCD Data finally works with PortC
    ; D0-3 to PC7-4
    ; D4-7 to PC3-0
; LCD CTRL as usual to PortA
    ; BE-RS to PORTA4-7
; LED to any of A/B/G (just use 4 pins)
    ; any 4 leds is fine. Just use G since close
; Keypad to PortF
    ; Port F is used for keypad, high 4 bits for column selection, low four bits for reading rows. On the board, RF7-4 connect to C3-0, RF3-0 connect to R3-0.
 
; What happens when a,b or c overflow?
    ; I assume it is invalid since they are meant to be 1byte
    ; Hence, I would exit/restart
    ; Overflow: check if r1 is 0, else, there is overflow into a 2 byte integer (which does not match specs and is therefore invalid)
 
.def col = r16                       ; Store current row/column being checked
.def row = r17
.def cMask = r18                     ; Row/column masks
.def rMask = r19
.def b = r20
.def c = r21
.def result = r22                    ; Stores result = b x c
.def second = r23                    ; 0 indicates currently writing b. 1 indicates currently writing c
.def temp1 = r24
.def temp2 = r25
 
;;;;;;;;; Keypad setup ;;;;;;;;;
.equ portFDir = 0xF0                    ; Set pin7-4 output/pin3-0 input
.equ rowMask = 0x0F                     ; So that we only check input from pin3-0
.equ initColMask = 0xEF                 ; Only 1st col set to 0 (0b 1110 1111)
.equ initRowMask = 0x01                 ; Only 1st row set to 1 (for logical AND)
 
;;;;;;;;; LCD setup ;;;;;;;;;
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4
.equ LCD_BF = 7
 
.include "m2560def.inc"
 
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; MACROS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 
 
.macro writeNumber                      ; Macro for writing number to register @0
    ldi temp1, 10                       ; Shift all decimal digits to the right
    mul @0, temp1                       ; by multiplying @0 by 10 and moving back to @0
    mov @0, r0
    mov temp1, r1
    cpi temp1, 0                        ; If b,c overflow, flash LEDs and restart everything
    brne overflow
    ldi temp1, '0'                      ; store '0' in case input is '0'
    cpi row, 3                          ; if 3rd row, num is 0
    breq writeNumberEnd                 ; If so, write '0' to led
    mov temp1, row                      ; Else, store number pressed to temp1
    lsl temp1                           ; new single digit (temp1) = 1 + 3row + col
    add temp1, row
    add temp1,col
    subi temp1, -1
    add @0, temp1                       ; Add this digit to the register @0
    subi temp1, -48                     ; add 48 to temp1 to convert to ASCII
writeNumberEnd:
    do_lcd_data temp1                   ; Write input (temp1) ASCII value to LCD
.endmacro
 
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
 
 
RESET:
    ser temp1
    out DDRG, temp1                     ; Setup LEDs for output from portC
    ldi temp1, portFDir
    out DDRF, temp1                     ; Setup keypad for output(pin7-4)/input(pin3-0) from portF
 
;;;;;;;;;;;;; INIT LCD
 
    ldi temp1, low(RAMEND)
    out SPL, temp1
    ldi temp1, high(RAMEND)
    out SPH, temp1
 
    ser temp1
    out DDRC, temp1
    out DDRA, temp1
    clr temp1
    out PORTC, temp1
    out PORTA, temp1
 
    do_lcd_command 0b00111000               ; 2x5x7
    ldi temp2, 5                            ; delay for 5ms
    rcall delay
    do_lcd_command 0b00111000               ; 2x5x7
    rcall sleep_1ms
    do_lcd_command 0b00111000               ; 2x5x7
    do_lcd_command 0b00111000               ; 2x5x7
    do_lcd_command 0b00001000               ; display off
    do_lcd_command 0b00000001               ; clear display
    do_lcd_command 0b00000110               ; increment, no display shift
    do_lcd_command 0b00001110               ; Cursor on, bar, no blink
 
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; START MAIN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 
 
;;;;;;;;; Main ;;;;;;;;;;
main:
    clr b                               ; reset b,c and result for start of a calculation
    clr c
    clr result
    clr second
resetMasks:
    ldi temp2, 250                      ; add 250ms delay
    rcall delay                         ; to reduce chance of registering a key press multiple times
    ldi cMask, initColMask              ; Set column mask to init mask
    clr col
 
;;;;;;;;; Scan Keypad ;;;;;;;;;;
colLoop:
    cpi col, 3                          ; Scan 3 columns of keypad (4th not used)
    breq resetMasks
    out PORTF, cMask                    ; Column mask. Determines which column set to 0
    ldi temp2, 30                       ; add 50ms delay
    rcall delay                         ; to reduce chance of registering a key press multiple times
    in temp1, PINF                      ; Read portF pins
    andi temp1, rowMask                 ; Use logical AND to check if any rows (pin3-0) set to 0
    cpi temp1, 0xF
    breq nextCol                        ; If not, jump to nextCol
    ldi rMask, initRowMask              ; Else, prepare for row scan
    clr row                             ; load initial row mask and row number
rowLoop:
    cpi row, 4                          ; Once all 4 rows scanned, move to next column
    breq nextCol
        ; temp1 contains pins in register
        ; we could remove temp2 if we read from pins each row loop (hence no need to store)
        ; However, temp2 required elsewhere anyway so no need to remove
    mov temp2, temp1
    and temp2, rMask                    ; logical AND with row mask to check if a particular row set
    breq execution                      ; found a set row. Execute and do something
    inc row                             ; else, continue to next row
    lsl rMask                           ; by lsl row mask
    jmp rowLoop                         ; and repeat the loop
nextCol:
    lsl cMask                           ; Prepare for next column by lsl column mask
    inc col                             ; lsl 0b1110 1111 -->
    jmp colLoop
 
;;;;;;;;; Process Keypad ;;;;;;;;;;
execution:                              ; Found a button pressed somewhere
    cpi row,3                           ; we have an operand or 0
    breq operand
writeB:                                 ; else input was a number
    cpi second, 1                       ; check if we are imputting to c (second == 1)
    breq writeC                         ; if not, call macro to add digit to b
    writeNumber b
    rjmp resetMasks                     ; Then start scanning again from the start (top-left)
writeC:                                 ; (second == 1), so currently writing to c
    writeNumber c                       ; Call macro to add new digit to c
    rjmp resetMasks                     ; Then start scanning again from the start (top-left)
operand:
    cpi col, 1                          ; Check if input was 0 (col 1)
    breq writeB                         ; If so, write to b or c depending on second
    cpi col, 2                          ; Check if button was # (compute result)
    breq compute
multiply:                               ; If not, button was * (multiply)
    ldi second, 1                       ; set second to 1 to indicate writing to second integer
    ldi temp1, '*'
    do_lcd_data temp1                   ; write '*' to LCD
    rjmp resetMasks                     ; Then start scanning again from the start (top-left)
compute:                                ; Button pressed was #
    mul b,c                             ; Compute (#) the result
    mov temp1, r1
    cpi temp1, 0                        ; check if overflow into r1 from multiplication
    brne overflow
    ldi temp1, '='
    do_lcd_data temp1
    mov result, r0                      ; result holds final result
    rcall displayResult
    rjmp end                            ; jump to main and reset everything
overflow:
    ldi temp1, 3                        ; Overflow so flash LEDs 3 times
flashLEDLoop:
    ser temp2
    out PORTG, temp2                    ; Turn LEDs on
    ldi temp2, 200
    rcall delay                         ; Delay for 0.2sec
    clr temp2
    out PORTG, temp2                    ; Turn LEDs off
    ldi temp2, 200
    rcall delay                         ; Delay for 0.2sec
    dec temp1
    brne flashLEDLoop
    rjmp end                           ; jump to main and reset everything
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
    lcd_set LCD_RS              ; Set LCD to read
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
    lcd_clr LCD_RS              ; set back to write
    ret
 
;;;;;;;;;; Function call. Check BF until LCD ready ;;;;;;;;;;
 
lcd_wait:                       ; function call. check busy flag until LCD ready
    push temp1
    clr temp1
    out DDRC, temp1             ; make portF input port
    out PORTC, temp1            ; activate pullup
    lcd_set LCD_RW              ; set to read(1) from LCD
lcd_wait_loop:
    nop
    lcd_set LCD_E               ; turn on enable pin
    nop
    nop
    nop
    in temp1, PINC              ; read from pinC and see if BF is set(busy)
    lcd_clr LCD_E
    sbrc temp1, LCD_BF          ; keep checking until no longer busy
    rjmp lcd_wait_loop
    lcd_clr LCD_RW              ; Set LCD back to write(0)
    ser temp1
    out DDRC, temp1             ; set portF back to output port
    pop temp1                   ; end function call
    ret
 
;;;;;;;;;; Delay Function Calls ;;;;;;;;;;
 
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead
 
sleep_1ms:                      ; close enough to 1ms
    push temp1                  ; 4 cycless
    push temp2
    ldi temp2, high(DELAY_1MS)  ; 2 cycles
    ldi temp1, low(DELAY_1MS)
delayloop_1ms:
    sbiw temp2:temp1, 1         ; 4 standard. 3 last
    brne delayloop_1ms
    pop temp2                   ; 4 cycles
    pop temp1
    ret                         ; 4 cycles
 
delay:
    rcall sleep_1ms
    subi temp2, 1
    brne delay
    ret
 
;;;;;;;;;; Display Result Function Call ;;;;;;;;;;
displayResult:                          ; second used as temp since no longer needed
    ldi second, 100
    clr temp2
displayResultLoop:
    cp result, second
    brlo displayResultDisplay           ; (result<temp1) Finished displaying digit so display digit
    sub result, second                  ; Else, subtract temp1 until result<temp1
    inc temp2                           ; Increment temp2 for every subtraction
    rjmp displayResultLoop
displayResultDisplay:
    ;cpi temp2, 0                       ; If digit is 0, skip (Commented out else skips significant figures)
    ;breq displayResultIncrement        ; Alternatively, account with a 3rd/4th temp value (but just UI issue)
    subi temp2, -48                     ; Else, display digit (ASCII = num+48)
    do_lcd_data temp2
displayResultIncrement:
    sbrc second, 6                      ; if bit 6 set
    rjmp displayResultHundred           ; digit is 100s (bit 6 set in 100)
    sbrc second, 1                      ; if bit 1 set
    rjmp displayResultTen               ; digit is 10s (bit 1 set in 10)
    rjmp displayResultOne               ; Else, single digits so jump to end
displayResultHundred:
    ldi second, 10                      ; 100s so shift to 10 and reset temp2
    clr temp2
    rjmp displayResultLoop
displayResultTen:
    ldi second, 1                       ; 10s so shift to 1 and reset temp2
    clr temp2
    rjmp displayResultLoop
displayResultOne:
    ret