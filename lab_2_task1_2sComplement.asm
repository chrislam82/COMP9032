.macro 2byte2sComplement			; Unused but can be used to perform 2s complement of integers > 1 byte in size (Hence neg cannot be used)
	ldi @2, 0xFF 					; perform 2-byte 2s complement of a(@1:@0) to flip its sign
	ldi @3, 0xFF					; Use temp(@3:@2) as a temp variable
	sub @2, @0						; subtract a from temp
	sub @3, @1
	subi @2, low(-1)				; then add 1 to temp
	sbci @3, high(-1)
	movw @0, @2						; move result in temp back into a
	movw @1, @3
	ldi @3, 1						; load 1 into tempH to indicate 2s complement was performed
.endmacro
