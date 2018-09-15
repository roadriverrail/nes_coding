; Background Palette Loader Demo For NES
;
; Following on from the hello world program, this program expands out into
; interactions with the NES PPU (Picture Processing Unit).  This does the bare
; minimum to draw the screen-- it disables all sprites and background graphics
; and fills the screen with the default color.
;
; Doing this requires some extra work.  Firsst off, the PPU is not immediately
; ready at power on.  Before interacting with it, you need to wait enough cycles
; for it to become ready.  There is a standard wait process employed in the
; reset vector.
;
; Loading information into the PPU involves poking specific memory addresses.
; On the NEW, the PPU and CPU are basically independent of each other and they
; each have their own RAM space (the PPU's is called VRAM).  Loading data into
; VRAM is done by setting the address by writing it, one byte at a time, to the
; PPUADDR ($2006) register.  After that, VRAM can be read and written to using
; lda or sta instructions from the PPUDATA ($2007) register.
;
; The PPU stores 4 different background palettes; each stores 3 colors.  A 4th
; color, the default background color, is stored at VRAM $3F00 and aliased at
; $3F04, $3F08, and $3F0C.  (They're also aliased at $3F10, $3F14, $3F18, and
; $3F1C).  Because any write to those aliases can change the background color,
; it's easier to treat the palette as containing FOUR colors, with the first
; one always being the same.
; 
; In this demo, all the palettes are the same.  It's actually one of the
; background palettes from Super Mario Brothers


.define PPUMASK      $2001
.define PPUSTATUS    $2002
.define PPUADDR      $2006
.define PPUDATA      $2007

.define BGPALETTE_HI $3F
.define BGPALETTE_LO $00

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

  lda #$00      ; color image, no sprites, no background
  sta PPUMASK

  ; request access to the background palette memory.  This starts at VRAM
  ; address $3F00.  VRAM is in a separate address space from RAM, so we access
  ; it via the use of PPUADDR and PPUDATA.  PPUADDR sets the address to access
  ; while PPUDATA is the data, one byte at a time.  When you access VRAM via
  ; PPUDATA, it auto-increments the address by default, making loops easier.

  ; Start at VRAM address $3F00
  lda #BGPALETTE_HI
  sta PPUADDR
  lda #BGPALETTE_LO
  sta PPUADDR

  ; prep the loop
  ldx #0

  ; load the background palette
paletteloop:
  lda bgpalette, X ; load from the bgpalette array
  sta PPUDATA      ; store in PPUDATA, PPU will auto-increment
  inx              ; increment the X (index) register
  cpx #16
  bne paletteloop  ; run the loop until X=16 (size of the palettes)


  ; The "hello world" sound from the previous exercise, so we know we made
  ; it to the end of the reset vector.
  lda #$01	; square 1
  sta $4015
  lda #$08	; period low
  sta $4002
  lda #$02	; period high
  sta $4003
  lda #$bf	; volume
  sta $4000
forever:
  jmp forever

nmi:
  rti ; Return from the NMI (NTSC refresh interrupt)


; The background colors are, in order:
; $22: pale blue
; $29: drab green
; $1A: forest green
; $0F: black
; Actual color fidelity varies based on emulator and monitor, but
; this gives a rough sense of the colors
;
; Also note that my practical experience shows me that you *must*
; load up all 4 palettes in order to get the PPU to be happy and
; draw your default color to the screen!

bgpalette:
  .byte $22, $29, $1A, $0F ; palette 0
  .byte $22, $29, $1A, $0F ; palette 1
  .byte $22, $29, $1A, $0F ; palette 2
  .byte $22, $29, $1A, $0F ; palette 3


; vectors declaration
.segment "VECTORS"
.word nmi
.word reset
.word 0

; The "hello world" program identified this as a space for ROM data.  That is
; technically true, but it misses a verey critical nuance.  This segment is for
; CHR-ROM, which is a space in ROM which the PPU directly loads into its memory
; for use in rendering the screen!  This is not the rodata section!  Your
; read-only data used in your program belongs in the STARTUP segment!

.segment "CHARS"
