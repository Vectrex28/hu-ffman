;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  HUFFMAN TEST - By Antoine Fantys - (C) FG Software, 2025
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  .list
  .mlist

  .zp			;; The one, the only... ZEROPAGE!!!

DrawLo:			.ds 1		;; Pointer for the drawing position of the text we're decompressing
DrawHi:			.ds 1
Decomp_PointerLo:	.ds 1		;; Pointer to the current "cursor" position on the compressed text.
Decomp_PointerHi:	.ds 1
VDC_current:		.ds 1
VDC_status:		.ds 1

  .bss			;; Everything outside the ZP

  .include "include/EQU.asm"

  .code
  .bank $0
  .org $E000

RESET:			;; Reset routine goes here

  SEI			;; Disable interrupts
  CSH			;; Gotta go fast
  CLD			;; Clear decimal mode

	;; Time to map in the I/O and the RAM. No extra ROM banks as it all fits in the 8KB fixed bank.

  LDA #$FF		;; Bank $FF - This is the I/O
  TAM #0		;; Transfer I/O to Memory Paging Reg 0 ($0000-$1FFF)
  TAX			;; Transfer A to X
  LDA #$F8		;; Bank $F8 - RAM
  TAM #1		;; Transfer RAM to Memory Paging Reg 1 ($2000-$3FFF)

	;; Mapping setup complete! Yay!!!

  TXS			;; Setup the Stack Pointer
  LDA VIDEOPORT		;; Load VDC status register (Clear interrupts and interrupts mask, $0000)
  LDA #$07		;; Set one bit...
  STA IRQOFF		;; ...In order to disable IRQs in the IRQ Mask for vsync/hysnc ($1402)
  STA IRQSTATUS		;; Acknowledge any pending interrupts ($1403)
  STZ TIMERCTRL		;; Store zero in the timer control ($0C01)

  ST0 #5		;; Select Register #5 of the VDC...
  ST1 #0		;; ...And write $0000 to it
  ST2 #0		;; This turns off the screen, and disables VDC interrupts

  STZ <$00		;; Set ZP $00 to zero
  TII $2000,$2001,$1FFF	;; Copy $2000 (ZP $00) to the next value in RAM ($2001) 1FFF times incrementally

  BSR Init_VDC

  BRA Setup_GFX

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; It's the VDC Init, innit?

Init_VDC:			;; Basically sets up the VDC with the data below.

  LDA #LOW(vdc_table)
  STA <$20EE
  LDA #HIGH(vdc_table)
  STA <$20EF
  CLY
.setupvdcloop
  LDA [CDbios_src],y
  BMI .initdone
  INY
  STA <VDC_current
  STA VIDEOREG
  LDA [CDbios_src],y
  INY
  STA VIDEODATA_LO
  LDA [CDbios_src],y
  INY
  STA VIDEODATA_HI
  BRA .setupvdcloop
.initdone

  LDA #%00000100
  STA COLOURCTRL

  RTS

vdc_table:	; VDC register data

 ;	.db $05,$00,$00		; CR    control register
	.db $06,$00,$00		; RCR   scanline interrupt counter
	.db $07,$00,$00		; BXR   background horizontal scroll offset
	.db $08,$00,$00		; BYR        "     vertical     "      "
	.db $09,$10,$00		; MWR   size of the virtual screen
	.db $0A,$02,$0B		; HSR +                 [$02,$0B]
	.db $0B,$3F,$04		; HDR | display size    [$3F,$04]
	.db $0C,$02,$0D		; VPR |
	.db $0D,$F0,$00		; VDW | Y size
	.db $0E,$03,$00		; VCR +
	.db $0F,$10,$00		; DCR   DMA control register
	.db $13,$00,$7F		; SATB  address of the SATB
	.db -1			; end of table!

	;; Screen is now off, and the RAM is all clear B-)

Setup_GFX:

  ST0 #$00			;; This just pops the chars onto VRAM.
  ST1 #$00
  ST2 #$10

  ST0 #$02
  TIA background, VIDEODATA_LO, $0600

  JSR ClearScreen

;;;;;;;;;;;;;;;; Here goes the actual Huffman decompression, complete with writing to background

  ST0 #$00
  LDA #$81
  STA <DrawLo			;; Start at $0081, so that we may see the text
  STA VIDEODATA_LO
  STZ <DrawHi
  STZ VIDEODATA_HI

  ST0 #$02

  LDA #LOW(text1)
  STA <Decomp_PointerLo
  LDA #HIGH(text1)
  STA <Decomp_PointerHi		;; Load a pointer to the first text's decompression

  JSR Decompress_Huffman

  ST0 #$00
  LDA #$A1
  STA <DrawLo			;; Start at $00A1, so that we may see the text - but on the other "page"
  STA VIDEODATA_LO
  STZ <DrawHi
  STZ VIDEODATA_HI

  ST0 #$02

  LDA #LOW(text2)
  STA <Decomp_PointerLo
  LDA #HIGH(text2)
  STA <Decomp_PointerHi		;; Load a pointer to the second text's decompression

  JSR Decompress_Huffman

  LDA #$02
  STA COLOURPORT

  STZ COLOURREG_LO
  STZ COLOURREG_HI

  TIA palette, COLOURDATA_LO, $0020

  LDA #%00000101		;; Palette and display stuff here.
  STA IRQOFF
  LDA #5
  STA <VDC_current
  STA VIDEOREG
  ST1 #$CC
  CLI

  JSR ClearSpritesHW		;; Clear any stray sprites so the text is not obstructed.

GameEngineDone:

  JMP GameEngineDone

NMI:

  RTI

IRQ2:

  RTI

IRQ1:

  RTI

TIMER:

  RTI

;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Clear the whole screen;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

ClearScreen:
  ST0 #$00
  ST1 #$00
  ST2 #$00

  ST0 #2

  CLY
  LDX #$0F
  ST1 #$2F
.clearscreenloop
  ST2 #$01
  DEY
  BNE .clearscreenloop
  DEX
  BPL .clearscreenloop
  RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;This clears the different sprites on the screen;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ClearSpritesHW:

  STZ <VDC_current
  ST0 #$00	;; $00 = MAWR
  ST1 #$00
  ST2 #$7F	;; Sprite data is at addy $7F00

  LDA #$02
  STA <VDC_current
  ST0 #$02	;; $02 = VWR
  CLX
.clearspritesloop		;;;;;;;;;;;;;; SPRITES LOOK LIKE THIS!!! ;;;;;;;;;;;;;;;;
  STZ VIDEODATA_LO		;;  
  STZ VIDEODATA_HI		;; ------YY YYYYYYYY	Y = Y pos, X = X pos, P = Pattern addy
  INX				;; ------XX XXXXXXXX	y = Y flip, x = X flip, C = Colour pal
  BNE .clearspritesloop		;; -----PPP PPPPPPPP	H = Height (00 = 16, 01 = 32, 11 = 64)
				;; y-HHx--W p---CCCC	W = Width  (0 = 16, 1 = 32)

  RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;This is our main Huffman decompression routine, outputting Huffman-compressed text to the screen!;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Decompress_Huffman:

  CLY				;; Y is the current position on HuffmanLookup, AKA the linear
				;; hex representation of our Huffman tree.
  BRA .loadnextbyte_huffman	;; We start by loading the first byte off the text data we point to.
.huffmanloop
  TXA				;; Grab the bit index stored in X (See below), and rotate one bit off to the left.
  ASL A
.superhuffmanloopspecial
  TAX				;; Keep the current bit index in X, so we don't need to reload a variable.
  BCC .nopositivebranch		;; If we hit a zero, we go to the "negative" tree branch
  LDA HuffmanLookup+1,y		;; This is in case of a 1 - the "positive" branch - Nodes are arrays of 2 bytes.
  BMI .nexthuffmanbit		;; If the result is negative (AKA bit 7 is set), we're not at a leaf yet.
  BRA .foundmatch		;; If it's positive, it's a leaf, AKA a character we will decompress.
.nopositivebranch
  LDA HuffmanLookup,y		;; This is the "positive" branch, the first of the 2 bytes in a branch node.
  BMI .nexthuffmanbit		;; If it's negative, it's not a leaf! Keep parsing!
.foundmatch
  JSR ProcessFoundChar_Huffman	;; Decompressed chars are literal positive values off the tree's leaf nodes.
  BMI .decomp_over		;; If this subroot returns a negative value, the decompression is over!
  CLA				;; If not, go back to 0, AKA the tree's root.
.nexthuffmanbit
  AND #$7F			;; Since negative values are the non-leaves, remove bit 7 to get the real
  TAY				;; index of the loaded node and put that in Y.
  CPX #$80			;; Check if we need to reload a new byte into the bit index
  BNE .huffmanloop		;; If not, loop
.loadnextbyte_huffman
  PHY				;; We need to keep Y for this as it can be accessed mid-tree parse.
  CLY
  LDA [Decomp_PointerLo],y	;; Load the current pointer index
  PLY
  INC <Decomp_PointerLo		;; Advance the pointer by $0001
  BNE .noinchi_decompptr
  INC <Decomp_PointerHi		;; If the Low part is $00, then we must increment the High part of our pointy boi.
.noinchi_decompptr
  SEC				;; Set carry...
  ROL A				;; ...Then rotate into A. That way, after rotating all of the bits out, the result
  BRA .superhuffmanloopspecial	;; will be $80, and only will be when the bits are rotated out.
.decomp_over
  RTS				;; We're done! Bye!

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;This processes a found text character within a huffman-encoded string;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ProcessFoundChar_Huffman:
  CMP #$30		;; Check for a line break
  BEQ .linebreak
  CMP #$31		;; Check for the string end character
  BEQ .enddecomp
  STA VIDEODATA_LO	;; This means we've hit a literal
  ST2 #$01		;; High byte will always be $01 in this test case.
.return_linebreak
  LDA #$69		;; We return with a positive (and arbitrary) value: Still decompressing.
  RTS
.linebreak
  ST0 #$00		;; Write the post-linebreak draw index to MAWR
  LDA <DrawLo		;; Increment the draw start pointer, then return as if we drew a regular char.
  CLC
  ADC #$40		;; Since we have 2 screens across, $40 makes a line break!
  STA <DrawLo
  STA VIDEODATA_LO	;; Save it not only to the soft screen position, but also to MAWR
  LDA <DrawHi
  ADC #$00
  STA <DrawHi
  STA VIDEODATA_HI	;; Do the required 16-bit operation!
  ST0 #$02		;; Back to VWR
  BRA .return_linebreak
.enddecomp
  LDA #$FF		;; We return with a negative value: The whole string has been decompressed.
  RTS

background:
  .incbin "huffman_test_BKG.pcr"

text1:
  .incbin "output/huffman_test_huffman.bin"

text2:
  .incbin "output/huffman_test_2_huffman.bin"

palette:
  .db $00,$00,$40,$00,$88,$00,$D1,$00,$19,$01,$62,$01,$AA,$01,$F3,$01
  .db $FD,$01,$50,$00,$A0,$00,$31,$01,$BA,$01,$43,$00,$8C,$00,$D4,$00

  .include "output/huffman_lookup.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;; Here be vectors

  .org $FFF6
  .dw IRQ2		;; IRQ2: Electric Boogaloo! (For BRKs, external IRQs like CD-ROM stuff, etc. IIRC)
  .dw IRQ1		;; VDC IRQ - Hblank and Vblank gubbins
  .dw TIMER		;; The Timer
  .dw NMI		;; The good ol' NMI (Though not used apparently, unlike the NES lelelelelelel)
  .dw RESET		;; If you don't know what that is you're even more of a boomer than I am :P

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;