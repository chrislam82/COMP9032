; COMP9032_project.asm
;
; Created: 9.11.2019
; Last Modified: 19.11.2019
; Version: 4.3.2
; 
; Created: Christopher Shu Chun Lam
;
; File description:
;			UNSW COMP9032 2019 T3 Project:
;			Program to simulate control operation on the opaqueness levels of smart windows in an airplane
;
; Wiring:
;	LED
;		LED0, LED1 --> PH8 (PortH pin5)		;Timer4CompareRegC --> Window1
;		LED2, LED3 --> PL2 (PortL pin5)		;Timer5CompareRegC --> Window2
;		LED4, LED5 --> PL3 (PortL pin4)		;Timer5CompareRegB --> Window3
;		LED6, LED7 --> PL4 (PortL pin3)		;Timer5CompareRegA --> Window4
;	LCD CTRL
;		BE-RS --> PA4-7
;	LCD DATA
;		D0-3 --> PC7-4	
;		D4-7 --> PC3-0
;	Push Button
;		PB0 --> RDX4
; 	Keypad
;		R3-R0 --> PF0-PF3					; 4 low bits for input (rows)
;		C0-C3 --> PF4-PF7					; 4 high bits for output (col)

.include "m2560def.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Registers ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Queue variables (For both queues; shared element positions)
;		queueHead=queueTail --> queues are empty
.def queueHead=r1							; Head of queues
.def queueTail=r2							; Tail of queues (next available address)

; Core program variables
.def timeCount=r3							; Current time in terms of number of number of centralTimer interrupts run since start
.def request=r22							; Represents requests from keypad

; Priority state control variables
.def emergencyState=r16						; (1) if emergency called recently (0) otherwise
.def centralState=r17						; Stores number of queued central control requests

; Keypad variables
.def colMask=r19							; Mask for determining which bit output 0 to keypad
.def col=r20								; col number
.def row=r21								; Stores input from keypad rows

; Temporary variables for general use
.def temp0=r23
.def temp1=r24
.def temp2=r25



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Other assembly directives ;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; NOTE: Directives that only relate or are used in a specific macro/interrupt/function/... are setup
;		within those sections of code, not here. These directive are used in multiple sections of code and/or
;		are important in understanding how program operates

; PWM signal strengths
;		--> Picked based on most discernable visual difference
;		--> According to specifications, "the brighter the LEDs, the darker the window"
.equ PWMclear=0								; level0: this is darkest LED (off)
.equ PWMlight=8								; level1
.equ PWMmedium=32							; level2
.equ PWMdark=0xFF							; level3: this is brightest LED

; LCD variables
;		Used for LCD operations
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BF = 7

; LCD DDRAM Addresses
;		LCD instruction to change current address in LCD data memory
;		--> Based on addresses/instructions in LCD Module User's Manual provided in COMP9032 course website
;		--> Address = Address in 2 line DDRAM + 0b_1000_000(128) to specify DDRAM
;		--> e.g >> do_lcd_command LCDaddressW1			; Sets data memory address to address of window1's level on LCD
.equ LCDaddressState=128
.equ LCDaddressW1=172
.equ LCDaddressW2=175
.equ LCDaddressW3=178
.equ LCDaddressW4=181

; Counter added to timeCount register to determine when requests in reqQueue are executed
;		OVF0 prescaler set to /1024
;		Time/interrupt = 256 * 1024 / 16_000_000 ~= 0.016384 sec/overflowInterrupt
;		Number of interrupts required = 0.5sec / 0.016384 ~= 30.52 = 31 (rounded up)
.equ overflowLoopCount = 31



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Data: in data memory (dseg) ;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 2 parallel circular queues for storing requests
;		-> Program uses 17ms counter based timer so there are at most 500/17 ~= 30 requests on a queue at any
;		   time given requests are popped off queue after 500ms. Hence queue size only needs to be >=30.
;		NOTE: using queue size of 256 allows head and tail tracker to loop from 255 to 0 given 1-byte registers by
;			  ignoring effect on SREG. However, this means taking into account effects of head/tail operations on SREG
.equ queueSize=256

.dseg
.org 0x0200
	reqQueue: .byte queueSize
	timeQueue: .byte queueSize

	; 4 variables in dseg for storing the current state/levels (0-3) of each window(1-4)
	win1_level:		.byte 1
	win2_level:		.byte 1
	win3_level:		.byte 1
	win4_level:		.byte 1
.cseg										; Set back to program memory (cseg)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;; MACROS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Macros: LCD macros ;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macros for LCD related operations

; >>>>>>>>>> REFERENCE <<<<<<<<<<
;	REFERENCE: UNSW COMP9032 2019 T3 Week 6 Sample Code (Provided by Hui Wu)
;		--> Additional macro do_lcd_data_reg modified from do_lcd_data macro

.macro do_lcd_command						; write a command to LCD instruction memory
    ldi temp1, @0
    rcall lcd_command
    rcall lcd_wait							; And wait until LCD BF flag clear
.endmacro
 
.macro do_lcd_data							; similar but write data to LCD data memory
    ldi temp1, @0
    rcall lcd_data
    rcall lcd_wait
.endmacro

.macro do_lcd_data_reg						; similar to do_lcd_data except copy values from another register
    mov temp1, @0
    rcall lcd_data
    rcall lcd_wait
.endmacro

.macro lcd_set								; Set an LCD CTRL bit in Port A
    sbi PORTA, @0
.endmacro
 
.macro lcd_clr								; Clr an LCD CTRL bit in Port A
    cbi PORTA, @0
.endmacro
; >>>>>>>>>> END OF REFERENCE <<<<<<<<<<



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Macros: LED macros ;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macros for LED related operations

; LED intialisation
.macro init_LEDs
	; Enable relevant pins used for PWM to LEDs to output
    ldi temp1, 0b_0011_1000					; Enable Port L bit3,4,5 as output
    sts DDRL, temp1
    ldi temp1, 0b_0010_0000					; Enable Port H bit5 as output
    sts DDRH, temp1

	; Set all windows to PWMclear (level 0) in Initial State (S:)
	ldi temp1, PWMclear						; PWMclear==0
    sts OCR5AH, temp1        
    sts OCR5AL, temp1
    sts OCR5BH, temp1
    sts OCR5BL, temp1
    sts OCR5CH, temp1
    sts OCR5CL, temp1
	sts OCR4CH, temp1
    sts OCR4CL, temp1

	; Enable and set clocks for Timer4,5 to standard with no prescaling
    ldi temp1, (1<<CS50)
    sts TCCR5B, temp1
    ldi temp1, (1<<CS40)
    sts TCCR4B, temp1

	; Set both timers to PWM, Phase Correct with top of 0xFF
	; Set all 4 compare registers to standard for Phase Correct to toggle on compare match
    ldi temp1, (1<<WGM50)|(1<<COM5A1)|(1<<COM5B1)|(1<<COM5C1)
    sts TCCR5A, temp1
    ldi temp1, (1<<WGM40)|(1<<COM4C1)
    sts TCCR4A, temp1
.endmacro

; Macro updates brightness of LEDs given a window level from DSEG
;		1. Take in byte address in DSEG (@0)
;		2. Determine the corresponding PWM level given window level
;		3. Load PWM level to address provided (@1)
;			NOTE: While compare reigster for Timer Overflows used are 2-byte, since timer set to compare only up to
;			a max of 0xFF, only low byte register value needs to be modified. High byte value is set at start to 0
.macro updateBrightness
	lds temp1, @0
	cpi temp1, 0
	breq clear
	cpi temp1, 1
	breq light
	cpi temp1, 2
	breq medium
dark:
	ldi temp1, PWMdark
	rjmp changeBrightness_end
medium:
	ldi temp1, PWMmedium
	rjmp changeBrightness_end
light:
	ldi temp1, PWMlight
	rjmp changeBrightness_end
clear:
	ldi temp1, PWMclear
changeBrightness_end:
	sts @1, temp1
.endmacro



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Macros: Queue macros ;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macros for queue related operations
;		NOTE: Need to push/pop X on stack frame during calls 

; Used for pushing request onto queues
.macro enablePushQueue						
	cbi PORTD, 1							; Activate INT1 (PORTD bit1) falling edge software interrupt to queue pushQueue interrupt
.endmacro

; Pop from front of queue and store in request register
.macro popReqQueue
	ldi XL, low(reqQueue)
	ldi XH, high(reqQueue)
	add XL, queueHead
	ld request, X							; Load value stored at front of reqQueue to request register
	
	inc queueHead							; Increment queueHead tracker (Hence releasing old heads of both queues)
.endmacro

; Check value of node at head of timeQueue for determining if request ready to be executed
.macro checkTimeQueueHead
	ldi XL, low(timeQueue)
	ldi XH, high(timeQueue)
	add XL, queueHead
	ld request, X							; Load value stored at front of timeQueue to request register
.endmacro



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Macros: Window level manipulation macros ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macros to inc/dec window levels with a max(level3) and min(level0)

.macro incLevel
	lds temp1, @0							; Load window level from dseg
	cpi temp1, 3							; If already level 3, do nothing (max level)
	breq incLevel_end
	inc temp1								; Else, increase level and write back to dseg
	sts @0, temp1
incLevel_end:
.endmacro

.macro decLevel
	lds temp1, @0							; Load window level from dseg
	cpi temp1, 0							; If already level 0, do nothing (min level)
	breq decLevel_end
	dec temp1								; Else, decrease level and write back to dseg
	sts @0, temp1
decLevel_end:
.endmacro



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;; IVT Initialisation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; IVT ordered based on order in m2560def.inc

.cseg
.org 0x0000									; Interrupt to run at program start/reset
	jmp RESET
.org INT0addr								; addr for External Interrupt Request0
	jmp emergency
.org INT1addr								; addr for External Interrupt Request1
	jmp pushQueue
.org OVF0addr								; addr for Timer Overflow Interrupt0
	jmp centralTimer

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;; INTERRUPTS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Interrupt: RESET ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Program initialisation / setup

RESET:
; >>>>>>>>>> REFERENCE <<<<<<<<<<
;	REFERENCE: UNSW COMP9032 2019 T3 Week 6 Sample Code (Provided by Hui Wu)
	; LCD init
    ldi temp1, low(RAMEND)					; Setup stack
    out SPL, temp1
    ldi temp1, high(RAMEND)
    out SPH, temp1
 
    ser temp1
    out DDRC, temp1							; Setup portC for LCD data
    out DDRA, temp1							; Setup portA for LCD CTRL
    clr temp1
    out PORTC, temp1						; Clear ports
    out PORTA, temp1
 
    do_lcd_command 0b00111000				; 2x5x7
    ldi temp2, 5							; delay for 5ms
    rcall delay
    do_lcd_command 0b00111000				; 2x5x7
    rcall sleep_1ms
    do_lcd_command 0b00111000				; 2x5x7
    do_lcd_command 0b00111000				; 2x5x7
    do_lcd_command 0b00001000				; display off
    do_lcd_command 0b00000001				; clear display
    do_lcd_command 0b00000110				; increment, no display shift
    do_lcd_command 0b00001110				; Cursor on, bar, no blink
; >>>>>>>>>> END OF REFERENCE <<<<<<<<<<

	; Initial LCD display
    do_lcd_data 'S'
    do_lcd_data ':'
    do_lcd_data ' '
    do_lcd_data 'W'
    do_lcd_data '1'
    do_lcd_data ' '
    do_lcd_data 'W'
    do_lcd_data '2'
    do_lcd_data ' '
    do_lcd_data 'W'
    do_lcd_data '3'
    do_lcd_data ' '
    do_lcd_data 'W'
    do_lcd_data '4'
    do_lcd_data ' '
    do_lcd_command LCDaddressW1				; Set 2nd line of LCD to position for window1's level
    do_lcd_data '0'
    do_lcd_data ' '
    do_lcd_data ' '
    do_lcd_data '0'
    do_lcd_data ' '
    do_lcd_data ' '
    do_lcd_data '0'
    do_lcd_data ' '
    do_lcd_data ' '
    do_lcd_data '0'

	; Setup timerOverflowInterrupt 0 (OVF0)
	clr temp1
	out TCCR0A, temp1
	ldi temp1, (1<<CS00) | (1<<CS02)		; Scale time counter by /1024 to increase time between interrupts
	out TCCR0B, temp1
	ldi temp1, 1<<TOIE0						; Activate overflow timer interrupt
	sts TIMSK0, temp1

	; Enable External Interrupts 0,1 with falling edge
	ldi temp1, (2<<ISC00) | (2<<ISC10)
	sts EICRA, temp1
	ldi temp1, (1<<INT0) | (1<<INT1)
	out EIMSK, temp1

	; Setup INT1 (Port D bit1) for software interrupt
	ldi temp1, 0b_0000_0010
	out DDRD, temp1
	out PORTD, temp1

	; Setup rows and columns for output and input from keypad
    ldi temp1, 0b_1111_0000
    out DDRF, temp1							; Setup keypad for output(pin7-4)/input(pin3-0) from portF

	; Enable global interrupt (I in SREG)
	sei

	; Initialise LEDs using init_LEDs macro
	init_LEDs

	; Initialise all tracking variables
	clr emergencyState
	clr centralState
	clr queueHead
	clr queueTail

	; Initialise all window levels in DSEG to 0
	clr temp1
	sts win1_level, temp1
	sts win2_level, temp1
	sts win3_level, temp1
	sts win4_level, temp1

	jmp main



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Interrupt: INT0: emergency ;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt raised when emergency request from emergency control called (Push Button)
;		1. Reset all window levels to 0 and write state and window levels to Interface like normal
;		2. Clear all trackers and set emergencyState to indicate emergency request called recently for resetting polling in main

emergency:
	push temp0
	in temp0, SREG
	push temp0

	clr temp0								; Set all window levels to 0
	sts win1_level, temp0
	sts win2_level, temp0
	sts win3_level, temp0
	sts win4_level, temp0
	rcall updateLCDemergency				; Then update all interface
	rcall updateInterface

	clr centralState						; Clear all tracking variables including queue (head==tail-->empty queue)
	mov queueHead, queueTail
	ldi emergencyState, 1					; Set emergencyState to ensure polling reset at main after exiting interrupt

	pop temp0
	out SREG, temp0
	pop temp0
	reti



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Interrupt: INT1: pushQueue ;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Software interrupt enabled by keypad polling and emergency (press button)
;		1. Stores whatever is in request register at tail of request queue
;		2. Repeats for time queue but with timer+overflowLoopCount so that request is exectued after 0.5sec (31 interrupts)
;		3. Increment queue tail

pushQueue:
	push temp0
	in temp0, SREG
	push temp0
	push XL
	push XH

	ldi XL, low(reqQueue)					; Load address of request queue in dseg
	ldi XH, high(reqQueue)
	add XL, queueTail						; Increment to address of current tail node in request
	st X, request							; And store request at that address

	ldi XL, low(timeQueue)					; Do similar with time queue in dseg
	ldi XH, high(timeQueue)
	add XL, queueTail
	mov request, timeCount					; except storing current timeCount + overflowLoopCount(31)
	subi request, -(overflowLoopCount)		; to store time to execute request
	st X, request
	
	inc queueTail							; Increment queueTail tracker to next available address for both Queues
	sbi PORTD, 1							; Setup INT1 (PORTD bit1) for next falling edge software interrupt

	pop XH
	pop XL
	pop temp0
	out SREG, temp0
	pop temp0
	reti



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Interrupt: OVF0: centralTimer ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Other core section of program. Timer used to check if the changes due to requests are ready for execution through using both queues
;		--> Prescaler set to /1024. Given clock frequency of 16Mhz, the interrupt runs approximately every 16.384ms
;		1. Checks if there are requests in queue and if request at front of queue is ready for execution
;		2. If so, branch to type of request depending on bits in request
;		3. Update window levels given type of request and indiivdual window bits in register for local control
;		4. Update interface with new values and current control state

.equ centralReq_bit=6						; indicates if request is from central control
.equ centralInc_bit=1						; indicates if request from central control is for increase to PWMdark
.equ centralDec_bit=0						; indicates if request from central control is for decrease to PWMclear
.equ localDir_bit=5							; indicates if request is for increases in local control if not from central control

centralTimer:
	push temp0
	in temp0, SREG
	push temp0
	push temp1
	push temp2
	push request
	push XL
	push XH
	inc timeCount							; Increase timeCount since new centralTimer interrupt called
centralTimer_checkRequest:
	cp queueHead, queueTail					; If queuehead==queueTail, queue is empty so exit interrupt
	breq centralTimer_end
	checkTimeQueueHead						; Else, check execution time for request at front of queue
	cp request, timeCount					; If still more time before ready for execution, do nothing and exit interrupt
	brne centralTimer_end
	popReqQueue								; Else, pop request from front of reqQueue, increase position of head node
centralTimer_processRequest:				; and process the request by branching to relevant type of request
	sbrs request, centralReq_bit
	rjmp centralTimer_locaReq
centralTimer_centralReq:					; Request is from central control
	rcall updateLCDcentral
	sbrs request, centralInc_bit			; If central request inc bit is clr, prepare temp1 to set all levels to dark (level 3)
	ldi temp1, 3
	sbrs request, centralDec_bit			; Else, central request is clear (level 0) and so clear temp1
	clr temp1
	sts win1_level, temp1					; Update window levels with temp1
	sts win2_level, temp1
	sts win3_level, temp1
	sts win4_level, temp1
	dec centralState						; Then decrease count of queued central requests
	rjmp centralTimer_updateInterface
centralTimer_locaReq:						; Request is from local control
	rcall updateLCDlocal					; Update LCD state and use function to update individual window levels based on bits for each window
	rcall updateLocalStates
centralTimer_updateInterface:
	rcall updateInterface					; Update UI for each window to their respective level (stored in DSEG) at end of request processing
;;;;;;;;;;;;;;;;;;;; End of Interrupt ;;;;;;;;;;;;;;;;;;;;
centralTimer_end:
	pop XH
	pop XL
	pop request
	pop temp2
	pop temp1
	pop temp0
	out SREG, temp0
	pop temp0
	reti



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;; PROGRAM MAIN: KEYPAD POLLING ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Polls keypad for input and pushes requests onto a queue for handling by centralTimer (OVF0 interrupt)
;		--> Converts row output (PINF) into request using masks and sets bits to determine characteristics of request
;		--> Counter based approach for debouncing and preventing multiple reads if a button is held too long
;		--> Prevents input from states with lower priority if a request from a higher priority state is currently in queue
; Keypad buttons:
;		centralState  -->   7(inc) ,*(dec)
;		localStateInc -->   2(win1) ,5(win2) ,8(win3) ,0(win4) 
;		localStateDec -->   3(win1) ,6(win2) ,9(win3) ,#(win4) 
.equ initColMask = 0b_1110_1111				; mask applied to cols. Start with only col0 set to 0
.equ rowMask = 0x0F							; mask applied to rows. Isolate input from rows only
.equ centralReqMask=0b_0000_1100			; mask applied to central requests. Sets unused rows

main:
	cpi emergencyState, 0					; If emergency called recently, clear all trackers
	brne postEmergency
	clr col									; Else, initialise col and colMask(temp0)
	ldi temp0, initColMask
keypadInput:
	cpi col, 3								; If col!=3, update colMask(temp0) depending on col value
	breq main
	sbrc col, 0								; if bit0 set (col==1)
	ldi temp0, 0b_1101_1111
	sbrc col, 1								; if bit1 set (col==2)
	ldi temp0, 0b_1011_1111					; else, leave colMask(temp0) at default value
	out PORTF, temp0						; and write colMask to keypad (PortF)
	rcall sleep_1ms
	ldi request, rowMask					; Init request to rowMask
keypadDebouncer:
	ldi temp2, 15							; Debouncing using counter(temp2) set to 15 (~=15ms) using counter based approach
keypadLoop:
	rcall sleep_1ms
	in row, PINF
	andi row, rowMask						; Only read row input from PINF using rowMask
	and request, row						; Use logical AND to update any cleared bits to request (to allow parallel input)
	cpi row, rowMask
	brne keypadDebouncer					; If input for loop!=0x0F, reset counter(temp2) since ground at row(s) recently
	dec temp2								; Else, dec counter(temp2) until 0
	cpi temp2, 0
	brne keypadLoop
	cpi request, rowMask 					; If request!=0x0F, at least 1 button was pressed on keypad so process
	breq keypadEnd							; Else, poll next col
keyPressed:
	cpi col, 0
	breq centralControl
localControl:								; If col > 0, input is local (inc/dec)
	sbrc col, 0								; If col1(bit1 set), set locaDir_bit to 1 to indicate local request for increase
	sbr request, (1<<localDir_bit)			
	enablePushQueue							; then push request onto queue using software interrupt (INT1)
	rcall sleep_1ms
	rjmp keypadEnd
centralControl:								; col==0, so request from central control
	sbr request, (3 << 2)					; Set bit 2,3 in request (Since they are unused buttons and invalid)
	cpi request, centralReqMask				; If inc&dec both pressed, or unused butttons pressed only, do nothing. Consider it invalid
	breq keypadEnd
	cpi request, rowMask
	breq keypadEnd
	sbr request, (1<<6)						; Else valid, so set bit to indicate request is a central request
	cpi centralState, 0
	brne centralControl_end					; If centralState==0,
	mov queueHead, queueTail				; entering centralState from a lower priority state so clear queue of requests (queueHead=queueTail)
centralControl_end:
	inc centralState						; increase count of queued central Control requests
	enablePushQueue							; Finally, push request onto queue using software interrupt (INT1)
	rcall sleep_1ms
	rjmp keypadEnd
postEmergency:								; If emergency recently called, reset all tracking variables to initial state
	mov queueHead, queueTail
	clr centralState
	clr emergencyState						; And reset emergencyState tracker to indicate post emergency request operations completed
	rjmp main
keypadEnd:
	cpi centralState, 0						; If any central requests queued, poll central requests only
	brne main
	inc col									; Else increment column and poll next column
	rjmp keypadInput



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;; FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Function Calls: LCD operations ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Function calls to:
;		--> Write to data memory
;		--> Write to instruction memory
;		--> Wait for BF to be clr

; >>>>>>>>>> REFERENCE <<<<<<<<<<
;	REFERENCE: UNSW COMP9032 2019 T3 Week 6 Sample Code (Provided by Hui Wu)
;		-> set  LCD_BF=7 as directive at top of file

lcd_command:								; LCD command to write to instruction memory
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
 
lcd_data:									; LCD command to write to data memory
    out PORTC, temp1
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
  
lcd_wait:									; Function reads from instruction memory until BF is clr (not busy)
    push temp1
    clr temp1
    out DDRC, temp1							; Set PortC to input
    out PORTC, temp1						; activate pullup
    lcd_set LCD_RW							; Set to read from LCD
lcd_wait_loop:
    nop
    lcd_set LCD_E
    nop
    nop
    nop
    in temp1, PINC
    lcd_clr LCD_E
    sbrc temp1, LCD_BF						; Read BF from LCD until clr (no longer busy)
    rjmp lcd_wait_loop
    lcd_clr LCD_RW							; Reset everything changed at start of function back to default
    ser temp1
    out DDRC, temp1
    pop temp1
    ret
; >>>>>>>>>> END OF REFERENCE <<<<<<<<<<



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Function Calls: Delay Functions ;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Functions for incurring delays

; >>>>>>>>>> REFERENCE <<<<<<<<<<
;	REFERENCE: UNSW COMP9032 2019 T3 Week 6 Sample Code (Provided by Hui Wu)
;		-> Modified register names
; sleep_1ms:
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead
 
sleep_1ms:
    push temp1
    push temp2
    ldi temp2, high(DELAY_1MS)
    ldi temp1, low(DELAY_1MS)
delayloop_1ms:
    sbiw temp2:temp1, 1
    brne delayloop_1ms
    pop temp2
    pop temp1
    ret
; >>>>>>>>>> END OF REFERENCE <<<<<<<<<<

; Dynamic delay. Delay depends on value stored in temp2 before function call.
delay:
    rcall sleep_1ms
    subi temp2, 1							; Dec temp2 for each loop
    brne delay								; Calls sleep_1ms until temp2==0
    ret										; Returns with temp2=0



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Function Call: updateInterface ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Called at end of centralTimer_processRequest or emergency interrupt
;		1. Updates LCD, LED interfaces for all window(1-4) levels after processing a request

updateInterface:
	push temp1

	lds temp2, win1_level					; For each window(1-4)
	subi temp2, -'0'
	do_lcd_command LCDaddressW1				; set LCD DDRAM address based on defined directive at top of file
	do_lcd_data_reg temp2					; Load level from DDRAM, convert to ASCII by adding '0' and write to LCD

	lds temp2, win2_level
	subi temp2, -'0'
	do_lcd_command LCDaddressW2
	do_lcd_data_reg temp2

	lds temp2, win3_level
	subi temp2, -'0'
	do_lcd_command LCDaddressW3
	do_lcd_data_reg temp2

	lds temp2, win4_level
	subi temp2, -'0'
	do_lcd_command LCDaddressW4
	do_lcd_data_reg temp2

	updateBrightness win1_level, OCR4CL		; Then for each window, 
	updateBrightness win2_level, OCR5CL		; update their brightness on LCD to the respective levels
	updateBrightness win3_level, OCR5BL
	updateBrightness win4_level, OCR5AL

	pop temp1
	ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Function Calls: update LCD state ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Called by centralTimer or emergency depending on type of request. For the associated control state:
;		1. Sets LCD DDRAM address to start of LCD based on defined directive at top of file for the desired state
;		2. Writes desired state to LCD

updateLCDemergency:
	push temp1
	do_lcd_command LCDaddressState			; Write state ('!!') to LCD
	do_lcd_data '!'
	do_lcd_data '!'
	pop temp1
	ret

updateLCDcentral:
	push temp1
	do_lcd_command LCDaddressState			; Write state ('C:') to LCD
	do_lcd_data 'C'
	do_lcd_data ':'
	pop temp1
	ret

updateLCDlocal:
	push temp1
	do_lcd_command LCDaddressState			; Write state ('L:') to LCD
	do_lcd_data 'L'
	do_lcd_data ':'
	pop temp1
	ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Function Call: updateLocalStates ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Called by centralTimer. Processes a request from local control:
;		1. Determines direction of local request (inc/dec) 
;		2. Adjust window levels for the requested windows (determined by clr bit).
;			-> Multiple windows changed if parallel requests
.equ localWin1_bit=3
.equ localWin2_bit=2
.equ localWin3_bit=1
.equ localWin4_bit=0

updateLocalStates:
	push temp1								; If localDir_bit set
	sbrs request, localDir_bit				; request is for increases to window levels
	rjmp dec_win1							; else, request is for decreases
; Process local control request for increasing window levels
inc_win1:
	sbrc request, localWin1_bit				; For each bit for windows in request
	rjmp inc_win2							; if bit clr, call macro to increase level if not at max
	incLevel win1_level
inc_win2:
	sbrc request, localWin2_bit
	rjmp inc_win3
	incLevel win2_level
inc_win3:
	sbrc request, localWin3_bit
	rjmp inc_win4
	incLevel win3_level
inc_win4:
	sbrc request, localWin4_bit
	rjmp updateLocalStates_end
	incLevel win4_level
	rjmp updateLocalStates_end
; Process local control request for decreasing window levels
dec_win1:
	sbrc request, localWin1_bit				; Similarly, for a decrease request, for each bit for windows
	rjmp dec_win2							; if bit clr, call macro to decrease level if not at min
	decLevel win1_level
dec_win2:
	sbrc request, localWin2_bit
	rjmp dec_win3
	decLevel win2_level
dec_win3:
	sbrc request, localWin3_bit
	rjmp dec_win4
	decLevel win3_level
dec_win4:
	sbrc request, localWin4_bit
	rjmp updateLocalStates_end
	decLevel win4_level
; end of function call so return
updateLocalStates_end:	
	pop temp1
	ret