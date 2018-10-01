; Drawing static sprites
; Now that we can confirm the palettes, pattern table, and nametable loading
; are all working, we can work with the next part of the NES PPU-- the sprite
; subsystem.
;
; Sprites are controlled by the Object Attribute Memory (OAM).  There are 64
; available entries in the OAM, with each specifying the coordinates and
; pattern for the sprite.  Sprites may be layered in front of or behind the
; background, too (see Super Mario Bros 3 for a classic example of behind-the-
; background sprite use).
;
; Technically, you can write to the OAM using addresses $2003 and $2004, called
; OAMADDR and OAMDATA, but this is not commonly done because address $4014
; manages a direct memory access (DMA) controller that can copy a complete OAM
; table from the page of your choice in memory.  By convention, most NES coders
; use $0200, so writing 2 to $4014 triggers a dump into the PPU's OMA table.
; The CPU is stalled during this transfer, so you need only make the write and
; then carry on with the code.

.define SPRITE_PAGE  $0200

.define PPUMASK      $2001
.define PPUSTATUS    $2002
.define PPUADDR      $2006
.define PPUSCROLL    $2005
.define PPUDATA      $2007

.define OAM_DMA      $4014

.define OAM_PAGE     2

.define NAMETABLE_0_HI $20
.define NAMETABLE_0_LO $00
.define ATTRTABLE_0_HI $23
.define ATTRTABLE_0_LO $C0
.define BGPALETTE_HI   $3F
.define BGPALETTE_LO   $00

; Mandatory iNES header.
.segment "HEADER"

.byte "NES", $1A ; "NES" magic value
.byte 2          ; number of 16KB code pages (we don't need 2, but nes.cfg declares 2)
.byte 1          ; number of 8KB "char" data pages
.byte $00        ; "mapper" and bank-switching type (0 for "none")
.byte $00        ; background mirroring flats
                 ;
                 ; Note the header is 16 bytes but the nes.cfg will zero-pad for us.

; code ROM segment
; all code and on-ROM program data goes here

.segment "STARTUP"

; reset vector
reset:
  bit PPUSTATUS  ; clear the VBL flag if it was set at reset time
vwait1:
  bit PPUSTATUS
  bpl vwait1     ; at this point, about 27384 cycles have passed
vwait2:
  bit PPUSTATUS
  bpl vwait2     ; at this point, about 57165 cycles have passed

  ; Interesting little fact I learned along the way.  Because it takes two
  ; stores on PPUADDR to move its pointer, it's good practice to start all of
  ; your PPUADDR use with a peek at PPUSTATUS since this resets its "latch"
  ; and ensures you're addressing the address you expect.
  ; Technically, we don't need this because we did it in the reset code, but
  ; it's a neat little thing to mention here

  bit PPUSTATUS

  ; load the palettes
  lda #BGPALETTE_HI
  sta PPUADDR
  lda #BGPALETTE_LO
  sta PPUADDR

  ; prep the loop
  ldx #0

; the palette loop now loads 8 palettes; 4 are for the background
; tiles and 4 are for sprites.  Before working with sprites, you
; must set sprite palette colors, or you'll have a bad time

paletteloop:
  lda bgpalette, X ; load from the bgpalette array
  sta PPUDATA      ; store in PPUDATA, PPU will auto-increment
  inx              ; increment the X (index) register
  cpx #32
  bne paletteloop  ; run the loop until X=32 (size of the palettes)

; move PPUADDR over to nametable 0. 
  lda #NAMETABLE_0_HI
  sta PPUADDR
  lda #NAMETABLE_0_LO
  sta PPUADDR

; set up Palette 0 for everything
  bit PPUSTATUS
  lda #ATTRTABLE_0_HI
  sta PPUADDR
 lda #ATTRTABLE_0_LO
  sta PPUADDR
  ldx #64 ; 64 tiles in the attribute table
  lda #0

attrloop:
  sta PPUDATA
  dex
  bne attrloop

; Now for the meat of this lab-- making a sprite.  This makes a
; basic character using tiles we already have at hand from last lab's
; pattern table.  Note that the character is made up of six 8x8 tiles
; and thus it takes six entries in the OAM to draw him.  It's common
; to think of "sprite" as "character," but on this early hardware,
; all sprites are fixed sizes expressed in either 8x8 or 8x16 tiles.
; So those 64 sprites don't go as far as it might seem!

; zero out the OAM DMA shadow page
  ldx #$FF
  lda $0
zero_oam:
  sta SPRITE_PAGE, X
  dex
  bne zero_oam

; refresh our index register...we're going to make heavy use of it
; now...

  ldx #0

; head
  lda #$7F             ; Y coordinate
  sta SPRITE_PAGE, X
  inx
  lda #$A0             ; Pattern bank 0, tile A0 (A1 is bottom)
  sta SPRITE_PAGE, X
  inx
  lda #$00             ; No flipping, in front of background, palette 0  
  sta SPRITE_PAGE, X
  inx
  lda #$7F             ; X coordinate
  sta SPRITE_PAGE, X
  inx
  lda #$7F             ; Y coordinate
  sta SPRITE_PAGE, X
  inx
  lda #$A1             ; Pattern bank 0, tile A0 (A1 is bottom)
  sta SPRITE_PAGE, X
  inx
  lda #$00             ; No flipping, in front of background, palette 0  
  sta SPRITE_PAGE, X
  inx
  lda #$87             ; X coordinate
  sta SPRITE_PAGE, X
  inx
; torso
  lda #$87             ; Y coordinate
  sta SPRITE_PAGE, X
  inx
  lda #$B0             ; Pattern bank 0, tile A0 (A1 is bottom)
  sta SPRITE_PAGE, X
  inx
  lda #$00             ; No flipping, in front of background, palette 0  
  sta SPRITE_PAGE, X
  inx
  lda #$7F             ; X coordinate
  sta SPRITE_PAGE, X
  inx
  lda #$87             ; Y coordinate
  sta SPRITE_PAGE, X
  inx
  lda #$B1             ; Pattern bank 0, tile A0 (A1 is bottom)
  sta SPRITE_PAGE, X
  inx
  lda #$00             ; No flipping, in front of background, palette 0  
  sta SPRITE_PAGE, X
  inx
  lda #$87             ; X coordinate
  sta SPRITE_PAGE, X
  inx
; feet
  lda #$8F             ; Y coordinate
  sta SPRITE_PAGE, X
  inx
  lda #$C0             ; Pattern bank 0, tile A0 (A1 is bottom)
  sta SPRITE_PAGE, X
  inx
  lda #$00             ; No flipping, in front of background, palette 0  
  sta SPRITE_PAGE, X
  inx
  lda #$7F             ; X coordinate
  sta SPRITE_PAGE, X
  inx
  lda #$8F             ; Y coordinate
  sta SPRITE_PAGE, X
  inx
  lda #$C1             ; Pattern bank 0, tile A0 (A1 is bottom)
  sta SPRITE_PAGE, X
  inx
  lda #$00             ; No flipping, in front of background, palette 0  
  sta SPRITE_PAGE, X
  inx
  lda #$87             ; X coordinate
  sta SPRITE_PAGE, X

; OAM DMA must always be a transfer from address XX00-XXFF, so we write
; the value of XX (in this case, 2) to OAM_DMA ($4014) to trigger the
; transfer

  lda #OAM_PAGE
  sta OAM_DMA 

; Enable background and sprite rendering.
  lda #$1e
  sta PPUMASK



forever:
  jmp forever

nmi:
  rti ; Return from the NMI (NTSC refresh interrupt)


; The background colors are, in order:
; $0F: black
; $15: red
; $22: blue
; $20: white

bgpalette:
  .byte $0F, $15, $22, $20 ; palette 0
  .byte $0F, $15, $22, $20 ; palette 1
  .byte $0F, $15, $22, $20 ; palette 2
  .byte $0F, $15, $22, $20 ; palette 3
spritepalette:
  .byte $0F, $07, $19, $20 ; palette 0
  .byte $0F, $07, $19, $20 ; palette 1
  .byte $0F, $07, $19, $20 ; palette 2
  .byte $0F, $07, $19, $20 ; palette 3


; vectors declaration
.segment "VECTORS"
.word nmi
.word reset
.word 0

; As mentioned above, this is the place where you put your pattern table data
; so that it can automatically be mapped into the PPU's memory at $0000-$1FFF.
; Note the use of .incbin so I can just import a binary file.  Neato!

.segment "CHARS"
.incbin "generitiles.pat"
