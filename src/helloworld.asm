; Hello World for the NES
;
; This initial program is purely to test out the assembling and linking
; features of cc65 and to prove out a build process that will make an
; iNES-format ROM suitable for use on most emulators.  There is no console
; output for the NES and no default set of characters for text output, so
; the traditional "Hello World" output has been replaced with generating a
; simple square wave on the audio synthesizer.  If your copy of mednafen is
; configured correctly for audio and everything builds correctly, you should
; hear a buzzing noise from the speakers and see a blank window/screen.
;
; The code to generate the square wave came from some code recommended by the
; NESDev Wiki at:
; https://wiki.nesdev.com/w/index.php/Programming_Basics#.22Hello.2C_world.21.22_program
;
; What was seriously lacking from this wiki, however, was information on how
; cc65 links together a complete ROM using the "-t nes" flag.  Hopefully, this
; code will help spare a future hobbyist some time in understanding how everything
; goes together.

; for reference on the linker config, I suggest you pull down the cc65 source and
; locate the "cfg/nes.cfg" file, which provides the layout of the ROM


; Mandatory iNES header.  Without this, the emulator will likely not load your ROM.
; cc65 declares its location and size in the nes.cfg file
.segment "HEADER"

.byte "NES", $1A ; "NES" magic value
.byte 2          ; number of 16KB code pages (we don't need 2, but nes.cfg declares 2)
.byte 1          ; number of 8KB "char" data pages
.byte $00        ; "mapper" and bank-switching type (0 for "none")
.byte $00        ; background mirroring flats
                 ;
                 ; Note the header is 16 bytes but the nes.cfg will zero-pad for us.

; Like with "HEADER", "STARTUP" is declared in the nes.cfg file.  Your code must
; fit within this 32 KB segment (for now).  All your code effectively goes here.
; I will not go into length on 6502 assembly, but I will note this loads a buzzy
; square wave into the audio synthesizer and then loops forever.  You must supply
; the label for your startup code in the "VECTORS" segment below

.segment "STARTUP"

reset:
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

; "VECTORS" is another mandatory section.  It must contain a table for three
; things, in order.  The first is for the non-maskable interrupt (NMI), which
; is the NTSC video signal vertical sync (among other things).  This interrupt
; triggers on the end of every pass of an NTSC television and is crucial for
; timing game logic.  The second is the entry point of your program, triggered
; off the "reset" interrupt which is delivered at power on and at any press of
; the NES reset button.  The third handles assorted interrupt requests (IRQs)
; from the system and is not used in this program.

.segment "VECTORS"
.word nmi
.word reset
.word 0

; "CHARS" is a reserved section for data.  Our program has no data, so this
; is only here to help the linker finish laying out the ROM.

.segment "CHARS"
