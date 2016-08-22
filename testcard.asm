;
;	ZX Diagnostics - fixing ZX Spectrums in the 21st Century
;	https://github.com/brendanalford/zx-diagnostics
;
;	Original code by Dylan Smith
;	Modifications and 128K support by Brendan Alford
;
;	This code is free software; you can redistribute it and/or
;	modify it under the terms of the GNU Lesser General Public
;	License as published by the Free Software Foundation;
;	version 2.1 of the License.
;
;	This code is distributed in the hope that it will be useful,
;	but WITHOUT ANY WARRANTY; without even the implied warranty of
;	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;	Lesser General Public License for more details.
;
;	testcard.asm
;

testcard

	ld sp, sys_stack
	call initialize

; Relocate the test card attribute string

	ld hl, str_testcardattr
	ld de, v_testcard
	ld bc, 5
	ldir

	ld a, BORDERWHT
	out (ULA_PORT), a

	call cls

	ld a, 8
	ld (v_width), a

	ld b, 24

testcard_print


; Draw top third of testcard

	ld b, 8

testcard_row

	ld a, b
	dec a
	ld (v_testcard + 3), a
	push bc
	ld b, 8

testcard_col

	ld a, b
	dec a
	ld (v_testcard + 1), a

	push bc
	ld hl, v_testcard
	call print
	ld hl, str_year
	call print

	pop bc
	djnz testcard_col

	pop bc
	djnz testcard_row

	; Top third done, copy the attributes down

	ld hl, 0x5800
	ld de, 0x5900
	ld bc, 0x100
	ldir
	ld hl, 0x5900
	ld de, 0x5a00
	ld bc, 0x100
	ldir

	; Do the Diagnostics banner
	ld hl, str_testcard_banner
	call print

	ld a, 6
	ld (v_width), a

	ld hl, str_testcard_message
	call print

	; Check AY Present flag
	ld hl, v_testcard_flags
	bit 0, (hl)
	ld hl, str_pageout_msg
	jr nz, print_pageout_msg

	ld hl, str_pageout_noay_msg

print_pageout_msg

	call print

	; Start the tone

tone_start

	call brk_check
	call read_kempston

	ld hl, v_testcard_flags
	bit 1, (hl)
	jr nz, check_testcard_keys

	ld b, 1
	call testcard_tone

check_testcard_keys

; Check for Q being pressed, go into quiet mode if so

	ld bc, 0xfbfe
	in a, (c)
	bit 0, a
	jr z, stop_beeper_tone

; Kempston stick right will do the same

	ld a, (v_kempston)
	bit 0, a
	jr nz, stop_beeper_tone

; As will right on Sinclair 1

	ld bc, 0xeffe
	in a, (c)
	bit 3, a
	jr z, stop_beeper_tone


;	Don't check for A being pressed if there's no AY present

  ld hl, v_testcard_flags
	bit 0, (hl)
	jr z, tone_start

;	Test if the A key is being pressed, if true then go into AY test mode

	ld bc, 0xfdfe
	in a, (c)
	bit 0, a
	jr z, start_ay_testing

; Kempston stick fire will do the same

	ld a, (v_kempston)
	bit 4, a
	jr nz, start_ay_testing

; As will fire on Sinclair 1

	ld bc, 0xeffe
	in a, (c)
	bit 0, a
	jr z, start_ay_testing

	jr tone_start

stop_beeper_tone

	ld hl, v_testcard_flags
	set 1, (hl)
	jp tone_start

;
;	Start reading and outputting AY tone data. Exit if BREAK is pressed.
;

start_ay_testing

	ld hl, str_aytest_msg
	call print
	call ay_reset
	ld hl, ay_test_data

ay_test_loop

	call brk_check
	ld a, (hl)
	cp AYCMD_DELAY
	jr nz, ay_test_1

	inc hl
	ld b, (hl)
	ld de, 0x1000

ay_test_delay

	dec de
	ld a, d
	or e
	jr nz, ay_test_delay
	ld de, 0x1000
	djnz ay_test_delay
	inc hl
	jr ay_test_loop

ay_test_1

	cp AYCMD_LOOP
	jr nz, ay_test_2
	ld hl, ay_test_data
	jr ay_test_loop

ay_test_2

	ld d, (hl)
	inc hl
	ld e, (hl)
	inc hl
	call ay_write
	jr ay_test_loop

;
;	end of main program
;	local subroutines
;


brk_check

	ld a, 0x7f
	in a, (0xfe)
	rra
	ret c					; Space not pressed
	ld a, 0xfe
	in a, (0xfe)
	rra
	ret c					; Caps shift not pressed

	call ay_reset			; Silence any AY tones

	call diagrom_exit		; Exit to BASIC or restart

; Sounds a tone followed by a pause
; Mimics the tone generated by the ROM test card routine in +2/+3 machines

testcard_tone
;	L register contains border colour to use
	ld l, 7
	BEEP 0x98, 0x380
	ld a, 0xff
	ld b, a
	xor a
	ld c, a

testcard_tone_delay

	nop
	nop
	nop
	nop
	nop
	dec bc
	ld a, b
	or c
	jr nz, testcard_tone_delay
	ret

;
;	Writes a value E to the AY register given in D
;
ay_write

	ld bc, AY_REG
	out (c), d
	ld bc, AY_DATA
	out (c), e
	ret

;
;	Resets the AY chip by writing zero to all registers.
;
ay_reset

	ld d, 0

ay_reset_loop

	ld bc, AY_REG
	out (c), d
	ld bc, AY_DATA
	out (c), 0
	inc d
	ld a, d
	cp 0x0f
	jr nz, ay_reset_loop

;	Test to see if the AY is present by reading from a register.

	ld bc, AY_REG
	xor a
	out (c), a
	in a, (c)
	cp 0
	ret nz

	ld hl, v_testcard_flags
	set 0, (hl)
	ret

;
;	Data for AY test
;
ay_test_data

	defb AYREG_A_VOL, 0, AYREG_B_VOL, 0, AYREG_C_VOL, 0, AYREG_MIX, 0x38

	defb AYREG_A_LO, 0x7E, AYREG_A_VOL, 0x0f
	defb AYCMD_DELAY, 0x15
	defb AYREG_A_VOL, 0x00
	defb AYCMD_DELAY, 0x05

	defb AYREG_B_LO, 0x7E, AYREG_B_VOL, 0x0f
	defb AYCMD_DELAY, 0x15
	defb AYREG_B_VOL, 0x00
	defb AYCMD_DELAY, 0x05

	defb AYREG_C_LO, 0x54, AYREG_C_VOL, 0x0f
	defb AYCMD_DELAY, 0x15
	defb AYREG_C_VOL, 0x00
	defb AYCMD_DELAY, 0x20

	defb AYREG_A_LO, 0xA8, AYREG_A_VOL, 0x0f
	defb AYCMD_DELAY, 0x15
	defb AYREG_A_VOL, 0x00
	defb AYCMD_DELAY, 0x05

	defb AYREG_B_LO, 0xA8, AYREG_B_VOL, 0x0f
	defb AYCMD_DELAY, 0x15
	defb AYREG_B_VOL, 0x00
	defb AYCMD_DELAY, 0x05

	defb AYREG_A_LO, 0x6f, AYREG_B_LO, 0x6f, AYREG_C_LO, 0x6f
	defb AYREG_A_VOL, 0x0f, AYREG_B_VOL, 0x0f, AYREG_C_VOL, 0x0f
	defb AYCMD_DELAY, 0x28


	defb AYREG_A_VOL, 0x0, AYREG_B_VOL, 0x0, AYCMD_DELAY, 0x08
	defb AYREG_A_VOL, 0x0f, AYREG_B_VOL, 0x0f, AYCMD_DELAY, 0x08
	defb AYREG_A_VOL, 0x0, AYREG_B_VOL, 0x0, AYCMD_DELAY, 0x08
	defb AYREG_A_VOL, 0x0f, AYREG_B_VOL, 0x0f, AYCMD_DELAY, 0x08
	defb AYREG_A_VOL, 0x0, AYREG_B_VOL, 0x0, AYCMD_DELAY, 0x08
	defb AYREG_A_VOL, 0x0f, AYREG_B_VOL, 0x0f, AYCMD_DELAY, 0x08
	defb AYREG_A_VOL, 0x0, AYREG_B_VOL, 0x0, AYCMD_DELAY, 0x08
	defb AYREG_A_VOL, 0x0f, AYREG_B_VOL, 0x0f, AYCMD_DELAY, 0x08

	defb AYCMD_DELAY, 0x20
	defb AYREG_A_VOL, 0x0, AYREG_B_VOL, 0x0, AYREG_C_VOL, 0x00
	defb AYCMD_DELAY, 0x10

	defb AYCMD_LOOP


;	The ZX Spectrum Diagnostics Banner

str_testcardattr

	defb	PAPER, 0, INK, 0, 0

str_year

	defb	BRIGHT, 0, 0x83, 0x81, BRIGHT, 1, 0x82, 0x87, 0

str_testcard

	defb	PAPER, 0, "    ", PAPER, 1, "    ", PAPER, 2, "    ", PAPER, 3, "    "
	defb	PAPER, 4, "    ", PAPER, 5, "    ", PAPER, 6, "    ", PAPER, 7, "    ", 0

str_pageout_msg

	defb	AT, 22, 0, PAPER, 0, INK, 7, BRIGHT, 1, " Hold: 'A'-AY test, 'Q'-quiet, BREAK-exit.", 0

str_pageout_noay_msg

	defb	AT, 22, 0, PAPER, 0, INK, 7, BRIGHT, 1, "    No AY. Hold: 'Q'-quiet, BREAK-exit.   ", 0

str_aytest_msg

	defb	AT, 22, 0, PAPER, 0, INK, 7, BRIGHT, 1, "    AY Test active, hold BREAK to exit.   ", 0

str_testcard_banner

	defb	AT, 18, 0, PAPER, 0, INK, 7, BRIGHT, 1
	defb    "                          "
	defb	TEXTNORM, PAPER, 0, INK, 2, 0x80, PAPER, 2, INK, 6, 0x80, PAPER, 6, INK, 4, 0x80
	defb	PAPER, 4, INK, 5, 0x80, PAPER, 5, INK, 0, 0x80, PAPER, 0, INK, 7, " "
	defb    TEXTBOLD, "                         "
	defb	TEXTNORM, PAPER, 0, INK, 2, 0x80, PAPER, 2, INK, 6, 0x80, PAPER, 6, INK, 4, 0x80
	defb	PAPER, 4, INK, 5, 0x80, PAPER, 5, INK, 0, 0x80, PAPER, 0,"  "
	defb    "                        "
	defb	TEXTNORM, PAPER, 0, INK, 2, 0x80, PAPER, 2, INK, 6, 0x80, PAPER, 6, INK, 4, 0x80
	defb	PAPER, 4, INK, 5, 0x80, PAPER, 5, INK, 0, 0x80, PAPER, 0,"   "

	defb	ATTR, 56, 0

str_testcard_message

	defb	AT, 19, 10, TEXTBOLD, BRIGHT, 1, INK, 7, PAPER, 0
	defb    "ZX Spectrum Diagnostics ", VERSION , ATTR, 56, 0
