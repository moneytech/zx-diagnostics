;
;	128K Specific Tests
;
;	Page 5 has already been tested (lower RAM), so just do pages 0,1,2,3,4,6 and 7.
;   	Page each one into the top 16K of RAM and perform the standard fill, inversion
;   	and random tests.
;   	Finally, do a paging test (only if the RAM checks pass, otherwise it
;   	can't be reliable).
;

test_128k

	ld hl, str_testingbank
	call print

;	Copy paging string to RAM where we can write to it

	ld hl, str_bankm
	ld de, v_paging
	ld bc, 3
	ldir

	ld b, 0

;	Test an individual RAM page.

test_ram_page
	
	ld a, b

;	Don't touch page 5. That's where the screen and sysvars live.
;	Plus we've already tested it via the 48K lower RAM tests.

	cp 5
	jp z, test_ram_page_skip

;	Page the target page in and write its index to the screen

	call pagein
	ld a, b
	or 0x30
	ld (v_paging), a
	ld hl, v_paging
	call print
	ld hl, str_dblbackspace
	call print

	xor a
	ld (v_fail_ic), a

;	Run the walk, inversion and random fill tests on the 
;	target page. Save BC beforehand as we're using that
;	to keep track of the current page being tested.
	
	push bc
	SAVESTACK
	WALKLOOP 49152,16384
	TESTRESULT128

	ALTPATA 49152, 16384, 0 
	ALTPATA 49152, 16384, 255
	ALTPATB 49152, 16384, 0
	ALTPATB 49152, 16384, 255
	TESTRESULT128

	MARCHTEST 49152, 16384
	TESTRESULT128
	
	RANDFILLUP 49152, 8192, 0
	RANDFILLDOWN 65534, 8191, 255
	TESTRESULT128

	RESTORESTACK
	pop bc

; Check if we got a failure for this bank

	push ix
	pop af
	cp 0

; 	Skip to test next page if not

	ld a, 60
	jr z, test_ram_page_next
	
	ld c, ixh

; 	Was this in a contended bank (1,3,5,7)?

	bit 0, b
	jr nz, test_ram_fail_contend

; 	No (0,2,4,8), store in appropriate sysvar

	ld a, (v_fail_ic_uncontend)
	or ixh
	ld a, ixh
	ld (v_fail_ic_uncontend), a
	out (LED_PORT), a
	ld a, 58
	jr test_ram_page_next

; 	Contended bank fail (1,3,5,7)

test_ram_fail_contend

	ld a, (v_fail_ic_contend)
	or ixh
	ld a, ixh
	ld (v_fail_ic_contend), a
	out (LED_PORT), a
	ld a, 58

;	Check if we've any more pages to test

test_ram_page_next
	
;	First write the pass/fail attribute back

	ld (v_attr), a
	ld hl, v_paging
	call print
	ld a, 56
	ld (v_attr), a

test_ram_page_skip

	inc b
	ld a, b
	cp 8
	jp nz, test_ram_page

; 	Now check if any errors were detected

	ld a, (v_fail_ic_contend)
	ld b, a
	ld a, (v_fail_ic_uncontend)
	or b
	jr z, test_ram_bank_pass

; 	Test failed - say so and abort 128K tests.
; 	No point in testing paging if we don't have
; 	reliable RAM to do so.

	ld hl, str_128ktestsfail
	call print
	
; 	If possible, output the failing IC's to the screen

	ld hl, str_check_ic
	call print

; 	Are we a toastrack?

	ld a, (v_toastrack)
	cp 1
	jr nz, not_a_toastrack

; 	Output failing IC's with Toastrack IC references

	ld a, (v_fail_ic_contend)
	ld d, a
	ld ix, str_128k_ic_contend
	call print_fail_ic

	ld a, (v_fail_ic_uncontend)
	ld d, a
	ld ix, str_128k_ic_uncontend
	call print_fail_ic
	jr test_ram_fail_end

; 	Output failing IC's with Grey +2 IC references

not_a_toastrack

	ld a, (v_fail_ic_uncontend)
	ld d, a
	ld ix, str_plus2_ic_uncontend
	call print_fail_ic

	ld a, (v_fail_ic_contend)
	ld d, a
	ld ix, str_plus2_ic_contend
	call print_fail_ic

;	Abandon test at this point

test_ram_fail_end

	ld hl, str_newline
	call print
	
	ret

;	RAM tests passed, now test the paging

test_ram_bank_pass

	ld hl, str_testingpaging
	call print
	
;	Fill all RAM pages (except page 5) with a pattern
;	that uniquely identifies the page
	
	;ld a, 64
	;FLASH

	ld b, 0

test_write_paging

	ld a, b
	cp 5
	jr z, skip_write_page5

;	Page target page in and write the pattern

	call pagein
	push bc
	ld hl, 0xc000
	ld de, 0xc001
	ld bc, 0x3fff

;	Ok, it's a really simple pattern (RAM page number) :)

	ld (hl), a
	ldir
	pop bc

skip_write_page5

	inc b
	ld a, b
	cp 8
	jr nz, test_write_paging

;	Pages all written, now page each one back in turn
;	and verify that the expected pattern is in each one.

	;ld a, 128
	;FLASH

	ld a, 0
	ld b, a

test_read_paging

;	Skip page 5 as per usual

	ld a, b
	cp 5
	jr z, skip_read_page5

;	Page in test page and write which one is being tested to the screen
	
	call pagein
	ld a, b
	or 0x30
	ld (v_paging), a
	ld hl, v_paging
	call print
	ld hl, str_dblbackspace
	call print

; Test the full page to see if it matches what was written

	ld hl, 0xc000

test_read_loop

	ld a, (hl)
	cp b

;	Non zero comparison means we've not got what we expected.
;	RAM all checks out (as far as we know), so this must be
;	a paging issue.

	jr nz, test_paging_fail

;	Otherwise continue testing

	inc hl
	ld a, h
	or l
	jr nz, test_read_loop

;	Attrs - red text 

	ld a, 60
	ld (v_attr), a

	ld hl, v_paging
	call print

;	Attrs back to normal black

	ld a, 56
	ld (v_attr), a

skip_read_page5

;	Any more pages to test paging with?

	inc b
	ld a, b
	cp 8
	jr nz, test_read_paging

;	All tests pass, we're all good. Nothing else to test so return.

	ld hl, str_128ktestspass
	call print
	
	ret

test_paging_fail

	ld a, 58
	ld (v_attr), a
	ld hl, v_paging
	call print
	ld a, 56
	ld (v_attr), a

;	Give the user the bad news

	ld a, 2
	out (ULA_PORT), a
	ld hl, str_newline
	call print
	ld hl, str_128kpagingfail
	call print

;	A paging fault is most likely the PAL/HAL chip so identify
;	whether we're a toastrack or not, then use this info to
;	inform the user which IC to check

	ld a, (v_toastrack)
	cp 0
	jr z, plus2_pal_msg
	ld hl, str_check_128_hal
	call print
	ret

plus2_pal_msg

	ld hl, str_check_plus2_hal
	call print
	ret

;
;	Overpaints attribute of page number to indicate previous pass/fail
;	Inputs: A=attribute to paint
;
	
set_page_success_status

	push hl
	push af

	ld a, (v_row)
	srl a
	srl a
	srl a
	and 3
	or 0x58
	ld h, a
	ld a, (v_row)
	sla a
	sla a
	sla a
	sla a
	sla a
	ld l, a
	ld a, (v_column)
	dec a
	dec a
	add a, l
	ld l, a

	pop af
	ld (hl), a
	pop hl
	ret