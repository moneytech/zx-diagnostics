;
;	Definitions and macros used by the testing ROM.
;

	define   LED_PORT	63
	define   ULA_PORT	254
	define   ROMPAGE_PORT   31
	define   BORDERRED	2
	define   BORDERGRN	4
	define	 BORDERWHT	7
	define   ERR_FLASH	#aa   ; alternate lights

;	ROM checksum values

	define	CRC_48K		0xFD5E
	define	CRC_128K	0xEFFC
	define	CRC_PLUS2	0x2AA3

	MACRO PAUSE
   
	exx
	ld bc, #ffff

.pauseloop

	nop
	nop
	nop
	nop
	nop
	djnz .pauseloop
	dec b    ; wrap b
	dec c
	jr nz, .pauseloop
	exx

	ENDM

; Flash the value in A twice

	MACRO FLASH

	ld b, 2

.flashloop      

	out (LED_PORT), a
	PAUSE
	ex af, af'
	ld a, 0
	out (LED_PORT), a
	ex af, af'
	PAUSE
	djnz .flashloop

	ENDM      


	MACRO WALKLOOP start, length
	ld hl, start
	ld de, length

.walk.loop

	ld a, 1
	ld b, 8     ; test 8 bits
	or a        ; ensure carry is cleared

.walk.checkbits

	ld (hl), a
	ld c, a     ; for compare
	ld a, (hl)
	cp c
	jr nz, .walk.borked
	rla
	djnz .walk.checkbits
	inc hl
	dec de
	ld a, d     ; does de=0?
	or e
	jp z, .walk.done
	jr .walk.loop

.walk.borked

; 	Store dodgy bit in ixh

	xor c

; 	And temporarily in d for BORKEDFLASH

	ld d, a
	ld bc, ix
	or b

;	Out straight to LED's, don't flash

	out (LED_PORT), a
	ld b, a
	ld a, 1	; Bit 0 of ixl: walk test fail
	or c
	ld c, a
	ld ix, bc
	ld a, BORDERRED
	out (ULA_PORT), a
	jr .walk.exit

.walk.done
.walk.exit

	ENDM

	MACRO BORKEDFLASH location

.borked
	ld a, BORDERRED
	out (ULA_PORT), a
	ld a, ERR_FLASH
	FLASH
	ld b, 4

.borked.loop

	ld a, d
	out (LED_PORT), a
	PAUSE
	ld a, 0
	out (LED_PORT), a
	PAUSE
	djnz .borked.loop

	ENDM


	MACRO BLANKMEM start, len, pattern

	ld hl, start
	ld de, len

.blankloop

	ld (hl), pattern
	inc hl
	dec de
	ld a, d
	or e
	jr nz, .blankloop

	ENDM

	MACRO ALTPATA start,len,fill

	BLANKMEM start, len, fill
	ld hl, start
	ld bc, len

.altpat1.wrloop1

	ld a, fill
	cpl
	ld (hl), a
	inc hl
	inc hl
	dec bc
	dec bc
	ld a, b
	or c
	jr nz, .altpat1.wrloop1

.altpat1.rd

	ld hl, start
	ld bc, len

.altpat1.rdloop1

	ld a, fill
	cpl
	cp (hl)
	jr nz, .altpat1.borked
	inc hl
	dec bc
	cpl
	cp (hl)
	jr nz, .altpat1.borked
	inc hl
	dec bc
	ld a, b
	or c
	jr nz, .altpat1.rdloop1 
	jr .altpat1.done

.altpat1.borked

; 	Store dodgy bit in ixh

	xor (hl)
	ld bc, ix
	ld d, a

; 	And also in d for ALTBORKED

	or b

;	OUT to led's

	out (LED_PORT), a
	ld b, a
	ld a, 2	; Bit 0 of ixl: inversion test fail
	or c
	ld c, a
	ld ix, bc

	ld a, BORDERRED
	out (ULA_PORT), a
	jr .altpat1.exit

.altpat1.done
.altpat1.exit

	ENDM

	MACRO ALTPATB start,len,fill
	BLANKMEM start, len, fill
	ld hl, start
	ld bc, len

.altpat2.wrloop1

	ld a, fill
	cpl
	inc hl
	ld (hl), a
	inc hl
	dec bc
	dec bc
	ld a, b
	or c
	jr nz, .altpat2.wrloop1

.altpat2.rd

	ld hl, start
	ld bc, len

.altpat2.rdloop1

	ld a, fill
	cp (hl)
	jr nz, .altpat2.borked
	inc hl
	dec bc
	cpl
	cp (hl)
	jr nz, .altpat2.borked
	inc hl
	dec bc
	ld a, b
	or c
	jr nz, .altpat2.rdloop1 
	jr .altpat2.done

.altpat2.borked

; 	Store dodgy bit in ixh

	xor (hl)
	ld bc, ix

; 	And also in d for ALTBORKED

	ld d, a
	or b
	out (LED_PORT), a
	ld b, a
	ld a, 2	; Bit 0 of l': inversion test fail
	or c
	ld c, a
	ld ix, bc
	ld a, BORDERRED
	out (ULA_PORT), a
	jr .altpat2.exit

.altpat2.done
.altpat2.exit	

	ENDM

;	Algorithm March X
;	Step1: write 0 with up addressing order;
;	Step2: read 0 and write 1 with up addressing order;
;	Step3: read 1 and write 0 with down addressing order;
;	Step4: read 0 with down addressing order. 
;	
; 	Credit - Karl (PokeMon) on WoS

	MACRO MARCHTEST start, len
	
	; Step 1 - write 0 with up addressing order
	; No errors expected with this part :)
	
	ld hl, start
	ld bc, len

.marchtest1.loop
	
	ld (hl), 0
	inc hl
	dec bc
	ld a, b
	or c
	jr nz, .marchtest1.loop
	
	; Step 2 - read 0 and write 1 with up addressing order
	
	ld hl, start
	ld bc, len

.marchtest2.loop
	ld a, (hl)
	cp 0
	jr z, .marchtest2.next
	
	MARCHBORKED
	jp .marchtest.done
	
.marchtest2.next
	ld a, 0xff
	ld (hl), a
	inc hl
	dec bc
	ld a, b
	or c
	jr nz, .marchtest2.loop

.marchtest3.start

	; Step 3 - read 1 and write 0 with down addressing order 
	ld hl, start
	ld bc, len - 1
	add hl, bc

.marchtest3.loop

	ld a, (hl)
	cp 0xff
	jr z, .marchtest3.next

	xor a 
	MARCHBORKED
	jp .marchtest.done
	
.marchtest3.next
	
	xor a
	ld (hl), a
	dec hl
	dec bc
	ld a, b
	or c
	jr nz, .marchtest3.loop
	
.marchtest4.start
	; Step 4 - read 0 with down addressing order
	ld hl, start
	ld bc, len - 1
	add hl, bc
	
.marchtest4.loop

	ld a, (hl)
	cp 0
	jr z, .marchtest4.next

	MARCHBORKED
	jp .marchtest.done
	
.marchtest4.next

	dec hl
	dec bc
	ld a, b
	or c
	jr nz, .marchtest4.loop

.marchtest.done

	ENDM

	MACRO MARCHBORKED
	
	ld b, a
	ld a, ixh
	or b
	ld ixh, a
	ld a, BORDERRED
	out (ULA_PORT), a	
	
	ENDM

; 	see http://map.tni.nl/sources/external/z80bits.html#3.2 for the
; 	basis of the random fill
; 	BC = seed

	MACRO RAND16

	ld d, b
	ld e, c
	ld a, d
	ld h, e
	ld l, 253
	or a
	sbc hl, de
	sbc a, 0
	sbc hl, de
	ld d, 0
	sbc a, d
	ld e, a
	sbc hl, de
	jr nc, .rand16.done
	inc hl

.rand16.done

	ld b, h
	ld c, l

	ENDM

;	Random fill test in increasing order
;	Args: addr - base address, reps - half memory size being tested,
;	      seed - PRNG seed to use

	MACRO RANDFILLUP addr, reps, seed

	ld iy, addr
	exx
	ld bc, seed  
	exx
	ld bc, reps

.randfill.up.loop      

	exx
	RAND16
	ld (iy), hl
	inc iy
	inc iy
	exx
	dec bc
	ld a, b
	or c
	jp nz, .randfill.up.loop

.randfill.up.test      

	ld iy, addr
	exx
	ld bc, seed      
	exx
	ld bc, reps

.randfill.up.testloop

	exx
	RAND16	; byte pair to test now in HL
	ld de, (iy) ; get corresponding pair of bytes from RAM
	inc iy
	inc iy
	ld a, h
	cp d
	jp nz, .randfill.up.borked1
	ld a, l
	cp e
	jp nz, .randfill.up.borked2
	exx
	dec bc
	ld a, b
	or c
	jp nz, .randfill.up.testloop
	jp .randfill.up.done

.randfill.up.borked1

	ld e, d	; bad byte should be in E
	ld l, h   ; expected byte in L 

.randfill.up.borked2

	ld a, e
	xor l
	
; 	Store dodgy bit in ixh

	ld bc, ix
	; And in D for borkedloop
	ld d, a
	or b
	out (LED_PORT), a
	ld b, a
	ld a, 4	; Bit 0 of l': random test fail
	or c
	ld c, a
	ld ix, bc
	ld c, a   ; save good byte
	ld a, BORDERRED
	out (ULA_PORT), a
	jp .randfill.up.exit

.randfill.up.done
.randfill.up.exit
	
	ENDM

;	Random fill test in descendingvorder
;	Args: addr - base address, reps - half memory size being tested,
;	      seed - PRNG seed to use

	MACRO RANDFILLDOWN addr, reps, seed

	ld iy, addr
	exx
	ld bc, seed  
	exx
	ld bc, reps
	
.randfill.down.loop      

	exx
	RAND16
	ld (iy), hl
	dec iy
	dec iy
	exx
	dec bc
	ld a, b
	or c
	jp nz, .randfill.down.loop

.randfill.down.test      

	ld iy, addr
	exx
	ld bc, seed      
	exx
	ld bc, reps
	
.randfill.down.testloop

	exx
	RAND16	; byte pair to test now in HL
	ld de, (iy) ; get corresponding pair of bytes from RAM
	dec iy
	dec iy
	ld a, h
	cp d
	jp nz, .randfill.down.borked1
	ld a, l
	cp e
	jp nz, .randfill.down.borked2
	exx
	dec bc
	ld a, b
	or c
	jp nz, .randfill.down.testloop
	jp .randfill.down.done

.randfill.down.borked1

	ld e, d	; bad byte should be in E
	ld l, h   ; expected byte in L 

.randfill.down.borked2

	ld a, e
	xor l
	
; 	Store dodgy bit in ixh

	ld bc, ix
	; And in D for borkedloop
	ld d, a
	or b
	out (LED_PORT), a
	ld b, a
	ld a, 4	; Bit 0 of l': random test fail
	or c
	ld c, a
	ld ix, bc
	ld c, a   ; save good byte
	ld a, BORDERRED
	out (ULA_PORT), a
	jp .randfill.down.exit

.randfill.down.done
.randfill.down.exit
	
	ENDM



	MACRO SAVESTACK
	ld (v_stacktmp), sp
	ENDM

	MACRO RESTORESTACK
	ld sp, (v_stacktmp)
	ENDM
	
	MACRO TESTRESULT
	ld bc, ix
	ld a, b
	cp 0
	jr nz, .test.fail

.test.pass

	ld hl, str_testpass
	call print
	jr .test.end

.test.fail

	ld a, (v_fail_ic)
	or b
	ld (v_fail_ic), a
	ld hl, str_testfail
	call print

.test.end

	ENDM

	MACRO TESTRESULT128

	ld bc, ix
	ld a, (v_fail_ic)
	or b
	ld (v_fail_ic), a

	ENDM

	MACRO PREPAREHREG

	exx
	ld a, 0
	ld h, a
	exx

	ENDM

;
;	Macro to sound a tone.
;	Inputs: L=border colour.
;
	MACRO BEEP freq, length

	ld de, length				

.tone.duration

	ld bc, freq			; bc = twice tone freq in Hz

.tone.period

	dec bc
	ld a, b
	or c
	jr nz, .tone.period

;	Toggle speaker output, preserve border

	ld a, l
	xor 0x10				
	ld l, a 
	out (0xfe), a

;	Generate tone for desired duration

	dec de					
	ld a, d
	or e
	jr nz, .tone.duration

	ENDM