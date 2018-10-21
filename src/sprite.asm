; Drawing sprite animation
;
; Since we previously drew a sprite by allocating its 6 tiles in the Object
; Attribute Memory (OAM), this time we get fancy and make it animate a little.
; Specifically, I'm using the 4-cell walk animation for the little person
; that was already laying around in the pattern table.
;
; There are, assurredly, more efficient ways to implement this, but this one
; was coded up with the layout of the pattern table in mind.  The pattern
; table layout is really more of the "easy to reason about" sort rather than
; one chosen for tighter code.
;
; In order to load the sprite, we're now using a subroutine called
; "load_sprite" which knows how to convert the current frame number and an
; initial x and y coordinate and load a 2x3 tile sprite from them.  You'll
; notice that this information is basically "passed" using "global variables."
; The 6502 has limited registers making the use of the stack for parameter
; passing pretty tricky.  Effective parameter passing is probably a lab on
; its own, so I skipped it.
;
; Because the pattern table entries needed to draw the sprite correctly are
; not arranged in a linear way, I created a little array called "anim" which
; describes each frame of the animation in a way that's coherent to the
; algorithm used in load_sprite.  It takes 6 pattern table entries to draw
; the character, so advancing to the next step in the animation is a matter
; of adding different multiples of 6 to "anim".
;
; To animate, you must change the image as time progresses, meaning you also
; need a timer.  This is where the other major point of this lab comes in--
; the non-maskable interrupt (NMI).  The NMI fires every time the PPU starts
; drawing another frame on the TV screen.  This gives us a "heartbeat" for our
; code and also serves as a general sense of time.  NTSC refreshes 60 fields
; (half-frames) per second, so we know that each trigger of the NMI is 1/60th
; of a second, and we can therefore decide how long to devote to each part
; of an animation.
;
; Also kindly note that we go ahead and do the OAM DMA immediately at the
; beginning of the NMI hander.  This is because the NMI signals the beginning
; of something called "vertical blanking" in the NTSC and PAL standards.  The
; OAM must be ready to go at end of vertical blanking so the image can be put
; on the screen, so we do it first and make sure we don't delay.  After that,
; we set up the next frame of animation.
;
; Finally...this is the first lab where we need RAM in order to track changing
; variables!  Astute observers might have noticed that all the memory we've
; declared up to this point has been RAM.  Since the variables we need are few,
; I've declared them in the "zero page", which is a RAM region already
; made available by the cc65 default NES configuration.  This is all a fancy
; way of saying that the first 256 bytes of addressable space are RAM, and
; because they're the first 256 bytes, the 6502 can fetch them very quickly.


.define SPRITE_PAGE  $0200

.define PPUCTRL      $2000
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

; "zero page" RAM
; This is where we're storing our mutable state.
.segment "ZEROPAGE"
current_frame:
  .byte 0
sprite_x:
  .byte 0
sprite_y:
  .byte 0
frame_count:
  .byte 0



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

; zero out the OAM DMA shadow page
  ldx #$FF
  lda $0
zero_oam:
  sta SPRITE_PAGE, X
  dex
  bne zero_oam

; Set up the sprite's base x and y coordinates
; and frame index (i.e. where in the animation we are)
; and then call load_sprite to do the hard work

  lda #$7F
  sta sprite_x
  sta sprite_y
  lda #0
  sta current_frame
  lda #0
  sta frame_count
; Load the sprite
  jsr load_sprite

; Enable background and sprite rendering.
  lda #$1e
  sta PPUMASK

; generate NMI
  lda #$80
  sta PPUCTRL

forever:
  jmp forever

nmi:
; OAM DMA must always be a transfer from address XX00-XXFF, so we write
; the value of XX (in this case, 2) to OAM_DMA ($4014) to trigger the
; transfer

  lda #OAM_PAGE
  sta OAM_DMA 

; Here we keep a count of the NMIs as they come in.  Until we count 15
; of them, which is roughly a quarter second, just keep holding on the
; existing sprite.
  inc frame_count
  lda frame_count
  cmp #15
  bne done
  lda #0
  sta frame_count

; We counted 15 NMIs, so let's update the animation frame and
; make the little character walk in place
  lda current_frame
  clc                   ; NEVER forget to clear the carry flag before adding
  adc #6                ; Each frame is an offset of a multiple of 6
  cmp #24               ; After 4 frames, wrap around (4*6 = 24)
  bne dont_cycle_anim
  lda #0
dont_cycle_anim:
  sta current_frame
done:
  jsr load_sprite
  rti                   ; Return from the NMI (NTSC refresh interrupt)



; load_sprite consults current_frame to determine the offset into anim
; and then draws the data in that row of anim into a 2x3 rectangle
.proc load_sprite
  ldx #0
  ldy current_frame
  lda #$7F
  sta sprite_x
  lda #$7F
  sta sprite_y
load_loop:
; First of two cells
  lda sprite_y
  sta SPRITE_PAGE, X
  inx
  lda anim, Y
  iny
  sta SPRITE_PAGE, X
  inx
  lda #$00
  sta SPRITE_PAGE, X
  inx
  lda sprite_x
  sta SPRITE_PAGE, X
  clc
  adc #7               ; move to right cell
  sta sprite_x
  inx
; Second of two cells
  lda sprite_y
  sta SPRITE_PAGE, X
  clc
  adc #7
  sta sprite_y
  inx
  lda anim, Y
  iny
  sta SPRITE_PAGE, X
  inx
  lda #$00
  sta SPRITE_PAGE, X
  inx
  lda sprite_x
  sta SPRITE_PAGE, X
  sbc #7              ; return to the left cell
  sta sprite_x
  inx
;; Loop if we haven't loaded the full sprite
  cpx #24
  bne load_loop
  lda sprite_y
  sbc #14
  sta sprite_y
  rts
.endproc


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

; The foreground/sprite colors are:
; $0F: black
; $07: dark brown
; $19: drab green
; $20: white

spritepalette:
  .byte $0F, $07, $19, $20 ; palette 0
  .byte $0F, $07, $19, $20 ; palette 1
  .byte $0F, $07, $19, $20 ; palette 2
  .byte $0F, $07, $19, $20 ; palette 3

; This describes each "frame" or "cell" of the walk animation.  I decided to
; write out an animation table rather than alter the pattern table.  This
; means that load_sprite is a little less efficient than it probably ought be,
; but makes the pattern table easier to visually think about in a debugger
; like fceux.  Each byte here is an address in the pattern table; you'll
; recognize them from the previous lab.

anim:
  .byte $A0, $A1, $B0, $B1, $C0, $C1 ; frame 1
  .byte $A2, $A3, $B2, $B3, $C2, $C3 ; frame 2
  .byte $A4, $A5, $B4, $B5, $C4, $C5 ; frame 3
  .byte $A6, $A7, $B6, $B7, $C6, $C7 ; frame 4

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
