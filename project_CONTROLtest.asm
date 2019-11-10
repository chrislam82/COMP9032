; project_CONTROLtest.asm
; Created: 06.11.2019
; Last Modified: 06.11.2019
; Version: 1.0.0
;       Testing use of, processing, and manipulating control registers

.include "m2560def.inc"
 
;3 temp values
.def temp0=r23
.def temp1=r24
.def temp2=r25
 
;3 control registers
.def control12=r20                      ; Control register for window 1,2
.def control34=r21                      ; Control register for window 3,4
.def controlPriority=r22                ; Control register for central control/emergency states
 
.equ win1_req=3
.equ win1_dir=2
.equ win1_level=0
.equ win2_req=7
.equ win2_dir=6
.equ win2_level=4
.equ win3_req=3
.equ win3_dir=2
.equ win3_level=0
.equ win4_req=7
.equ win4_dir=6
.equ win4_level=4
.equ central_req=1
.equ central_dir=0
.equ emergency_req=2
.equ win1_changing=4
.equ win2_changing=5
.equ win3_changing=6
.equ win4_changing=7
    ; (...)_req   --> (1) specifies that direction in dir is currently requested. (0) indicates there is no current request for a change in level
    ; (...)_dir   --> (1) specifies a request to inc opaqueness. (0) specifies a request to dec opaqueness. req must be set to (1) for a dir change to be executed
    ; (...)_changing --> (1) specifies that a window is currently changing so don't accept/process any new requests. (0) means window not changing so ready to accept/process requests
        ; changing, req and dir work together to store requests and for processing later
    ; (...)_level --> specifies the current state/opaqueness level of winx (2-bit binary to represent level 0-3)
 
.equ levelMask13=0b_0000_0011
.equ levelMask24=0b_0011_0000
    ; masks to extract current level at each window
 
main:
    ldi control12, 0b_1010_0111             ; win2 in state 2. Want to decrease to 1
    rcall process_level_2
 
end:
    rjmp end
 
process_level_2:
    push temp1
    push temp2
    mov temp1, control12
    andi temp1, levelMask24                 ; (logical and with mask)
    lsr temp1
    lsr temp1
    lsr temp1
    lsr temp1
process_2_increase:
    sbrs control12, win2_dir                ; If win2_dir=1, request is for increase
    rjmp process_2_decrease
    ; cbi with max/min, if at it already, do nothing. rjmp to process_2_load
    inc temp1
    rjmp process_2_load
process_2_decrease:                         ; else request is for decrease
    ; cbi with max/min, if at it already, do nothing. rjmp to process_2_load
    dec temp1
process_2_load:
    lsl temp1                               ; shift new level to correct position
    lsl temp1
    lsl temp1
    lsl temp1
    ldi temp2, levelMask24                  ; clear level in control register
    com temp2
    and control12, temp2
    eor control12, temp1                    ; then use XOR to load new level into control register'
    cbr control12, win2_req                 ; request completed so set control bit to 0
    pop temp2
    pop temp1
    ret



Think about it more clearly, what is meant to happen?
    - When a button is pressed:
        - If window is ready, a request is registered into the control registers (Overriding any previously stored requests)
        - If window is not ready, do nothing (Currently considered as transitioning levels. Necessary to ensure request bit is not set where set specifies a pending request)
    - When polling, at the end, polling checks if window is ready.
        - If window is ready, then it checks if there is a request
        - If window not ready, continue polling
    - window is ready and checking whether there is a request
        - If there is a queued request, activate TimerOverflowINT and set ready flag to 0 (not ready since currently processing) 
        - If there is no queued request, continue polling
    - Once TimerOverflowINT executes,
        - Execute changes to everything
        - Reset ready flag
        - Set req to 0 (request fulfilled)
        - Deactivate TimerOverflowINT















