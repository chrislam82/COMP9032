; queue.asm
;	File: Implementing a 256 element push/pop queue array in assembly
;
;	Comments:
;		Just need to make sure that X is not used for anything else
;		Also, just need to make sure that operations around push/pop do not rely on SREG. Else, need some manipulation before/after macro

.include "m2560def.inc"

.def queueHead=r16				; Current head of queue
.def queueTail=r17				; Next available address
								; If head = tail, then queue empty
.def timeCount=r18

.def temp0=r23
.def temp1=r24
.def temp2=r25

; Circular queue
; Since keypad input requires at least 30ms to debounce for processing another request, there is at most 500/30 ~= 16.67 ~= 17 pushes/0.5sec. Hence, queue size needs to be >= 17 . Hence, queueSize=256 is more than enough
; implementing with queueSize 256 allows head and tail trackers to loop back to 0 given max 1byte value of 255 without having to check bounds during queue operations
.equ queueSize=256

.dseg
.org 0x0200
	reqQueue: .byte queueSize
	timeQueue: .byte queueSize

.cseg

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Macros ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Push value (@0) and time+31 (+0.5sec) to end = of queue
.macro pushQueue
	; Push value (@0) to end of reqQueue
	ldi XL, low(reqQueue)
	ldi XH, high(reqQueue)
	add XL, queueTail
	st X, @0

	; Push timerCount+31 to end of timeQueue
	ldi XL, low(timeQueue)
	ldi XH, high(timeQueue)
	add XL, queueTail
	mov @0, timeCount
	subi @0, 31
	st X, @0

	; Increment queueTail tracker to next available address for both Queues
	inc queueTail
.endmacro

; Pop from front of queue and store in @0
.macro popQueue
	; Load value stored at front of queue to @0
	ldi XL, low(reqQueue)
	ldi XH, high(reqQueue)
	add XL, queueHead
	ld @0, X

	; Increment queueHead tracker
	inc queueHead
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Main ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
main:
	; Push 3 onto queue
	ldi temp0, 6
	pushQueue temp0
	ldi temp0, 4
	pushQueue temp0
	ldi temp0, 2
	pushQueue temp0

	; Pop 3 off queue
	popQueue temp1
	popQueue temp1
	popQueue temp1
end:
	rjmp end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;