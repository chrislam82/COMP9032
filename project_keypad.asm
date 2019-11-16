; keypad.asm
; 	File:
; 		Testing keypad input operations for project

; Wiring
; 	Keypad to PortF
; 		Port F is used for keypad, high 4 bits for column selection, low four bits for reading rows. On the board, RF7-4 connect to C3-0, RF3-0 connect to R3-0.
; 	LED
; 		PortC

; 4 windows that can be done in parallel
; 		2 keys for each window
; 		2 for central control
; 		emergency is PB
; Need 4 rows for local control
; Check central control first
; If central control is pressed, then ignore local control
; Add central control to queue. That way, we don't just

; What happens when push button is pressed?
; 	Enter a 0.5sec polling loop. Write state, clear all queues, and wait 0.5sec before setting everything to 0

; What happens when central control is pressed?
; 	2 scenarios
; 		1. Currently in another state. Write state, clear queue and push central control request onto queue
; 		2. Currently in central state. No need to clear queue. Just push onto queue
; 	To differentiate between the two, then I would need an indicator of whether I am in central state or local state

; What happens in local state then?
; 		1. We need to check that flag for central state is not set
; 		2. Then we simply need to poll
; 		3. If any input, then write local state and push request onto queue

.include "m2560def.inc"

.def centralState=r20
.def centralDir=r21
;	--> centralState inc every call in a certain direction (Determines number of queued centralControl calls)
;	--> CentralDir determines which direction current request is
;	--> If state already set, dir needs to be different for a dir to be requested (else, technically, everything is changing)
;	--> In main polling loop, if centralState!=0, then currently waiting for a central to run. just jump back to start of keypad polling
;.def emergencyState=r3 <------- lets not use it for now due to timing issues. Easy to add back in later
;	--> Set if emergency called
;	--> If I am already in emergency and I press emergency again, question is: Do I delay 0.5sec?
;	--> If emergency called, set to 1
;	--> If anything else called, set to 0
;		--> Add to main interrupt check
;	--> If set to 1 and interrupt called again, do nothing, just return from interrupt
.def col=r16
.def row=r17
.def request=r18

.def temp0=r22
.def temp4=r23
.def temp1=r24
.def temp2=r25

;;;;;;;;; Keypad setup ;;;;;;;;;
.equ portFDir = 0xF0                    ; pin7-4 output/pin3-0 input for keypad
.equ initColMask = 0b11101111           ; Only 1st col (C0) set to 0
.equ rowMask = 0x0F

.org 0x0000
	jmp RESET

RESET:
	; setup LED for output
	ser temp1
	out DDRC, temp1
	clr temp1
	out PORTC, temp1

	; Setup rows and columns for output and input from keypad
    ldi temp1, portFDir
    out DDRF, temp1                     ; Setup keypad for output(pin7-4)/input(pin3-0) from portF

	jmp main

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Main ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.equ centralReqMask=0b_0000_1100

main:										; Reset of keypad polling
	clr col
	ldi temp1, initColMask
keypadInput:								; New column polling
	cpi col, 3
	breq main
	sbrc col, 0
	ldi temp1, 0b_1101_1111
	sbrc col, 1
	ldi temp1, 0b_1011_1111
	out PORTF, temp1
	rcall sleep_1ms
	ldi request, rowMask
keypadDebouncer:
	ldi temp2, 10							; Debouncing using counter set to 10 (~=10ms). Count number of initial states (0x0F) from PINF. Reset if not 0x0F indicating input from other buttons or bouncing
keypadLoop:
	rcall sleep_1ms
	in row, PINF
	andi row, rowMask
	and request, row						; Update request with any new buttons
	cpi row, rowMask
	brne keypadDebouncer					; If not == 0x0F, then some input/bouncing. Reset count (temp2) and loop
	dec temp2
	cpi temp2, 0							; Else decrease count until count == 0
	brne keypadLoop
	cpi request, rowMask 					; If request==0x0F, nothing pressed during loop so move to next column
	breq keypadEnd
keyPressed:									; Else, at least 1 button pressed during loop so process
	cpi col, 0
	breq centralControl
localControl:								; If col > 0, input is local (inc/dec)
	sbrc col, 0								; If bit0 in col set, then col=1 (inc)
	sbr request, (1<<7)						; Set indicator on bit7 of request
	out PORTC, request
	;rcall pushQueue
	rjmp keypadEnd
centralControl:								; col==0
	sbr request, (3 << 2)					; Set bit 2,3 in row to 1 (Since they serve no purpose)
	cpi request, centralReqMask				; If inc&dec pressed, or unused butttons pressed only, do nothing. Consider it invalid
	breq keypadEnd
	cpi request, rowMask
	breq keypadEnd
	; sbr request, (1<<6)					; This is just for visibility for LED
	cpi centralState, 0
	brne centralControl_end
	; clr queueHead							; Entering centralState so clear queue of local requests
	; clr queueTail
centralControl_end:
	; inc centralState						; increase number of queued central Control requests
	out PORTC, request
	; rcall pushQueue						; Then push request onto queue
	rjmp main
keypadEnd:
	cpi centralState, 0						; If any central requests queued, poll for central requests only
	brne main								; Else increment column and poll next column
	inc col
	rjmp keypadInput

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