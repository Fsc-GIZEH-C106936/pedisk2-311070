;This is a bit correct disassembly of the PEDISK II ROM
;Based on work by Lee Davison 2013-07-04

drive_sel    = $e900    ;Drive Select Latch (??)
                        ;  bit function
                        ;  === ======
                        ;  7-4 not used
                        ;  3   motor ??
                        ;  2   drive 3 select
                        ;  1   drive 2 select
                        ;  0   drive 1 select

fdc          = $e980    ;WD1793 Floppy Disk Controller
fdc_cmdst    = fdc+0    ;  Command/status register
fdc_track    = fdc+1    ;  Track register
fdc_sector   = fdc+2    ;  Sector register
fdc_data     = fdc+3    ;  Data register

;WD1793 Floppy Disk Controller
;
;    Command           b7 b6 b5 b4 b3 b2 b1 b0
;I   Restore           0  0  0  0  h  V  r1 r0
;I   Seek              0  0  0  1  h  V  r1 r0
;I   Step              0  0  1  T  h  V  r1 r0
;I   Step-In           0  1  0  T  h  V  r1 r0
;I   Step-Out          0  1  1  T  h  V  r1 r0
;II  Read Sector       1  0  0  m  S  E  C  0
;II  Write Sector      1  0  1  m  S  E  C  a0
;III Read Address      1  1  0  0  0  E  0  0
;III Read Track        1  1  1  0  0  E  0  0
;III Write Track       1  1  1  1  0  E  0  0
;IV  Force Interrupt   1  1  0  1  i3 i2 i1 i0
;
;   r1 r0  Stepping Motor Rate
;    1  1   30 ms
;    1  0   20 ms
;    0  1   12 ms
;    0  0   6 ms
;     V      Track Number Verify Flag (0: no verify, 1: verify on dest track)
;     h      Head Load Flag (1: load head at beginning, 0: unload head)
;       T      Track Update Flag (0: no update, 1: update Track Register)
;       a0     Data Address Mark (0: FB, 1: F8 (deleted DAM))
;       C      Side Compare Flag (0: disable side compare, 1: enable side comp)
;       E      15 ms delay (0: no 15ms delay, 1: 15 ms delay)
;       S      Side Compare Flag (0: compare for side 0, 1: compare for side 1)
;       m      Multiple Record Flag (0: single record, 1: multiple records)
;           i3 i2 i1 i0    Interrupt Condition Flags
;              i3-i0 = 0 Terminate with no interrupt (INTRQ)
;                    i3 = 1 Immediate interrupt, requires a reset
;                    i2 = 1 Index pulse
;                    i1 = 1 Ready to not ready transition
;                    i0 = 1 Not ready to ready transition
;
;status bits         bit when 1
;                    === ======
;                     7  drive not ready
;                     6  write protect
;                     5  write error
;                     4  seek error
;                     3  crc error
;                     2  track zero/lost data
;                     1  data request
;                     0  busy
;

fretop      = $30       ;Pointer: Bottom of string storage
frespc      = $32       ;Pointer: Utility string
memsiz      = $34       ;Pointer: Highest address used by BASIC
chrget      = $70       ;Subroutine: Get Next Byte of BASIC Text
txtptr      = $77       ;Pointer: Current Byte of BASIC Text

l_b7        = $b7       ;memory pointer low byte
l_b8        = $b8       ;memory pointer high byte

ptrget      = $c12b     ;find a variable
l_d722      = $d722     ;output A as a two digit hex Byte
l_d78d      = $d78d     ;evaluate a hex digit

chrout      = $ffd2     ;KERNAL Send a char to the current output device
getin       = $ffe4     ;KERNAL Read a char from the current input device

    *=$e800

under_io:
;these two pages are under the I/O area ($e800-e9ff) area and can't be
;read.  the contents should not matter.
    !byte $04,$45,$45,$05,$07,$80,$c5,$44,$7f,$ff,$df,$ff,$f7,$df,$fb,$ff
    !byte $00,$04,$01,$04,$41,$05,$80,$05,$fe,$ff,$ff,$fb,$ff,$fb,$fb,$bf
    !byte $44,$41,$45,$45,$05,$24,$24,$25,$ff,$ff,$d7,$ff,$ff,$ff,$ff,$ff
    !byte $04,$04,$01,$45,$05,$04,$80,$04,$ff,$ff,$fd,$ff,$ff,$ff,$fe,$fb
    !byte $7b,$fa,$7a,$fe,$ba,$ff,$fb,$3a,$00,$00,$04,$00,$00,$05,$45,$40
    !byte $fa,$7a,$be,$de,$fb,$bb,$be,$bb,$04,$20,$00,$40,$01,$01,$04,$00
    !byte $3e,$16,$bf,$fa,$fe,$bf,$fa,$fe,$00,$00,$00,$01,$00,$00,$00,$04
    !byte $d2,$ba,$7a,$ff,$fa,$da,$7a,$fa,$01,$01,$00,$04,$40,$00,$40,$05
    !byte $46,$c4,$95,$05,$c4,$02,$43,$44,$ff,$ff,$ff,$fb,$ff,$ff,$ff,$ff
    !byte $21,$23,$81,$41,$45,$05,$45,$c0,$bf,$bf,$ff,$bf,$ff,$ff,$ff,$ff
    !byte $a7,$65,$0c,$24,$10,$01,$04,$01,$ff,$ff,$eb,$ff,$ff,$fb,$9f,$bb
    !byte $05,$c5,$42,$04,$95,$84,$14,$00,$ff,$fb,$fe,$fb,$bb,$ff,$ff,$fb
    !byte $fe,$dc,$fa,$bc,$9a,$4b,$fa,$7b,$00,$00,$00,$00,$00,$40,$00,$04
    !byte $b3,$fa,$7a,$fe,$ff,$1a,$fa,$ba,$00,$04,$2c,$04,$80,$00,$44,$04
    !byte $7a,$1a,$f2,$78,$ff,$3e,$3a,$5a,$00,$00,$20,$00,$00,$00,$00,$01
    !byte $fa,$fe,$3e,$fa,$fb,$ff,$be,$ba,$00,$20,$48,$0c,$00,$20,$00,$05
    !byte $c5,$25,$c5,$c5,$c1,$25,$64,$21,$df,$ff,$ff,$fb,$fe,$ff,$df,$ff
    !byte $01,$65,$04,$05,$91,$14,$04,$01,$fa,$fe,$ff,$ff,$ff,$ff,$f7,$fb
    !byte $85,$02,$07,$40,$46,$20,$04,$01,$ff,$ff,$fb,$bf,$ff,$fb,$df,$ff
    !byte $80,$01,$44,$40,$05,$40,$04,$04,$ff,$bf,$ff,$ff,$df,$bf,$ff,$fb
    !byte $ff,$7a,$9a,$79,$ca,$ba,$bb,$ab,$00,$41,$00,$00,$00,$00,$44,$00
    !byte $fb,$f3,$fb,$ab,$3e,$fa,$b8,$bb,$00,$40,$04,$04,$00,$00,$40,$84
    !byte $8a,$fa,$3f,$fb,$3b,$7a,$7f,$5b,$44,$20,$00,$04,$00,$00,$00,$c0
    !byte $ff,$ba,$ff,$fb,$7e,$fa,$fe,$fe,$44,$00,$04,$41,$04,$44,$08,$00
    !byte $05,$40,$45,$8d,$04,$d5,$67,$44,$ff,$ff,$ff,$bf,$fb,$bf,$fa,$ff
    !byte $20,$05,$05,$04,$55,$e6,$85,$44,$bb,$ff,$bf,$ff,$ff,$ff,$ff,$ff
    !byte $24,$45,$84,$45,$05,$45,$41,$04,$ff,$fb,$ff,$ff,$ff,$ff,$bb,$ff
    !byte $00,$af,$c5,$05,$81,$85,$21,$05,$df,$ff,$ff,$ef,$fb,$fb,$ef,$ff
    !byte $ff,$7a,$fa,$fe,$ff,$fe,$fa,$da,$00,$44,$00,$04,$00,$00,$40,$05
    !byte $fa,$ba,$6a,$ba,$db,$bb,$bf,$fe,$04,$40,$00,$04,$00,$00,$04,$20
    !byte $bb,$9a,$bf,$fa,$5b,$fb,$7a,$7b,$00,$00,$00,$02,$40,$00,$00,$00
    !byte $da,$aa,$fb,$bf,$fe,$fe,$7e,$3e,$04,$04,$00,$44,$00,$00,$04,$20

l_ea00:
    jmp init            ;Initialize the system (SYS 55904)
    jmp edit_memory     ;Display/edit memory ("ADDR?")
    jmp read_sectors    ;Read <n> sector(s) to memory
    jmp write_sectors   ;Write <n> sector(s) to disk
    jmp find_file       ;Search for filename in the directory
    jmp perform_load    ;Perform !LOAD

l_ea12:
    !word $7812-1       ;vector for !SYS
    !word l_ee98-1      ;vector for !LOAD
    !word $7800-1       ;vector for !SAVE
    !word $7803-1       ;vector for !OPEN
    !word $7806-1       ;vector for !CLOSE
    !word $7809-1       ;vector for !INPUT
    !word $780c-1       ;vector for !PRINT
    !word $780f-1       ;vector for !RUN
    !word $7815-1       ;vector for !LIST

l_ea24:
    !byte $9e           ;token for SYS
    !byte $93           ;token for LOAD
    !byte $94           ;token for SAVE
    !byte $9f           ;token for OPEN
    !byte $a0           ;token for CLOSE
    !byte $85           ;token for INPUT
    !byte $99           ;token for PRINT
    !byte $8a           ;token for RUN
    !byte $9b           ;token for LIST

    !byte $ff,$00       ;unused ??

l_ea2f:
; drive select byte
    !byte $01           ;drive 0 select bit pattern
    !byte $02           ;drive 1 select bit pattern
    !byte $04           ;drive 2 select bit pattern

l_ea32:
;get BASIC byte patch
;this is called by a JMP written to the get BASIC byte routine at $79
;
    CMP #'!'            ;compare the character with "!"
    bne l_ea44          ;if not "!" go test ":"

; found a "!" character

    sty $7f8a           ;save Y

    ldy #$01            ;set the index to the following byte
    lda (txtptr),y      ;get the following byte
    bmi l_ea4c          ;if it's a token go test it

    ldy $7f8a           ;restore Y
    lda #$21            ;restore A
l_ea44:
    CMP #':'            ;compare the character with ":"
    bcs l_ea4b          ;if >= ":" just exit

    jmp $007d           ;else return to get BASIC byte routine

l_ea4b:
    rts


l_ea4c:
;test a token following a "!" character
;
    cld                 ;clear decimal mode
    stx $7f89           ;save X
    tsx                 ;copy the stack pointer
    stx $7f8b           ;save the stack pointer

; save the top 32 bytes of the stack page, done with interrupts disabled

    ldx #$1f            ;set the byte count/index
    sei                 ;disable interrupts
l_ea57:
    lda $01e0,x         ;get a stack page byte
    sta $7fe0,x         ;save it
    dex                 ;decrement the byte count/index
    bpl l_ea57          ;loop if more to do

    txs                 ;set the stack pointer to $FF

; stack is saved so enable the interrupts again

    cli                 ;enable interrupts
    jsr chrget          ;get the next BASIC byte
    ldx #$08            ;set the test index to the last entry
l_ea67:
    cmp l_ea24,x        ;compare the token byte with a table token
    beq l_ea71          ;if they match go try to execute the command

    dex                 ;decrement the index
    bpl l_ea67          ;loop if more to do

    bmi l_ea87          ;else go do disk error $01, illegal command/mode
                        ;  branch always

; the token byte matches a table token

l_ea71:
    cpx #$08            ;compare the index with the index for !LIST
    beq l_ea84          ;if it is the index for !LIST go do it

    cpx #$02            ;compare the index with the index for !SAVE
    bcs l_ea8c          ;if >= !SAVE continue

; !SYS and !LOAD get some special treatment
;
; check we're in immediate mode or go do an error

    ldy $37             ;get the current BAISC line number high byte
    iny                 ;increment it
    bne l_ea87          ;if executing a program go do disk error $01, illegal
                        ;  command/mode

; else we're in immediate mode

    txa                 ;copy the index
    bne l_ea8c          ;if it's !LOAD go handle it like any other command

    jmp $7812           ;else go do !SYS

; go do !LIST

l_ea84:
    jmp $7815           ;do !LIST

; do disk error $01, illegal command/mode

l_ea87:
    lda #$01
    jmp l_ec8e

; found a match and the execution mode is ok

l_ea8c:
    txa                 ;copy the index
    asl                 ;* 2 bytes per vector
    tax                 ;back to the index
    lda l_ea12+1,x      ;get the vector high byte
    pha                 ;push it on the stack
    lda l_ea12,x        ;get the vector low byte
    pha                 ;push it on the stack
    jmp l_edbd          ;get a filename from a string or variable then do RTS
                        ;to call the vector

init:
;Initialize the system
;
    cld                 ; clear decimal mode
    lda #<$7800
    sta memsiz          ;BASIC top of memory low byte
    sta fretop          ;BASIC end of strings low byte
    lda #>$7800
    sta memsiz+1        ;BASIC top of memory high byte
    sta fretop+1        ;BASIC end of strings high byte

    lda #<$77ff
    sta frespc          ;utility string pointer low byte
    lda #>$77ff
    sta frespc+1        ;utility string pointer high byte

; display the startup message

    lda #<banner        ;set the message pointer low byte
    ldy #>banner        ;set the message pointer high byte
    jsr puts            ;message out

; test the RAM, well one byte of it at $78F2 anyway

    ldx #$f2            ;set the index/test byte
l_eab8:
    txa                 ;copy X
    eor #$ff            ;invert it
    sta $7800,x         ;save it to RAM
    dex                 ;decrement the index
    bpl l_eab8          ;loop if more to do, branch never

    ldx #$f2            ;set the index/test byte
l_eac3:
    txa                 ;copy X
    eor #$ff            ;invert it
    cmp $7800,x         ;compare it with the previously saved version
    beq l_eace          ;if they're the same just continue

    jmp puts_mem_err    ;else do "MEM ERROR" message and return

l_eace:
    dex                 ;loop if more to do, branch never
    bpl l_eac3

    lda #$ff
    sta $7e80
    sta $7ea0
    sta $7ec0
    sta $7ee0

    ; load the boot code into memory @ $7800

    lda #<$7800         ;set the memory pointer low byte
    sta l_b7            ;save the memory pointer low byte
    lda #>$7800         ;set the memory pointer high byte
    sta l_b8            ;save the memory pointer high byte

    ldx #$00            ;set track zero
    stx $7f92           ;save the WD1793 track number

    inx                 ;set drive 0
    stx $7f91           ;save the drive select latch copy

    ldx #$0d            ;set the sector count
    stx $7f96           ;save the sector count

    ldx #$09            ;set the sector number
    stx $7f93           ;save the WD1793 sector number

    jsr read_sectors    ;read <n> sector(s) to memory ??
    bne l_eb0b          ;if any error go deselect the drives, stop the motors
                        ;and exit to BASIC

; the boot code loaded so patch the get BASIC byte routine

    lda #$4c            ;set JMP opcode
    sta $79             ;save the JMP opcode
    lda #<l_ea32        ;set the JMP address low byte
    sta $7a             ;save the JMP address low byte
    lda #>l_ea32        ;set the JMP address high byte
    sta $7b             ;save the JMP address high byte


l_eb0b:
; deselect the drives and stop the motors ??
;
    lda #$08
    sta drive_sel       ;save the drive select latch
    rts


banner:
    !text $93,"PEDISK II SYSTEM",$0d
    !text "CGRS MICROTECH",$0d
    !text "LANGHORNE,PA.19047 C1981",$0d,$00


mem_error:
    !text $0d,"MEM ERROR",$00


puts_mem_err:
    lda #<mem_error     ;set the message pointer low byte
    ldy #>mem_error     ;set the message pointer high byte
    jmp puts            ;message out and return


l_eb5e:
;restore the top 32 bytes of the stack page and return EOT
;
    ldx #$1f            ;set the byte count/index
    sei                 ;disable interrupts
l_eb61:
    lda $7fe0,x         ;get a saved stack page byte
    sta $01e0,x         ;restore it
    dex                 ;decrement the byte count/index
    bpl l_eb61          ;loop if more to do

    ldx $7f8b           ;get the saved stack pointer
    txs                 ;restore it
    cli                 ;enable interrupts
    ldy $7f8a           ;restore Y
    ldx $7f89           ;restore X
    lda #$00            ;return an End Of Text byte
    jmp l_ea44          ;return to the get BASIC byte patch


l_eb7a:
; output a [SPACE] character
;
    lda #$20            ;set [SPACE]
    jmp chrout          ;do character out and return


l_eb7f:
;output [SPACE] <A> as a two digit hex Byte
;
    pha                 ;save A
    jsr l_eb7a          ;output a [SPACE] character
    pla                 ;restore A


l_eb84:
;output A as a two digit hex Byte
;
    sta $7f8d           ;save X
    stx $7f8e           ;save A
    jsr l_d722          ;output A as a two digit hex Byte
    ldx $7f8e           ;restore X
    lda $7f8d           ;restore A
    rts


disk_error:
    !text $0d,"DISK ERROR",$00


l_eba0:
;TODO ?
;
    lda #$00            ;clear A
    sta $7f94           ;clear the WD1793 status register copy
    sei                 ;disable interrupts

    lda $7f91           ;get the drive select latch copy
    beq l_ec08          ;if zero go do disk error $14, no disk selected

    lda drive_sel       ;read the drive select latch
    and #$07            ;mask the drive select bits
    cmp $7f91           ;compare it with the drive select latch copy
    beq l_ebcd          ;if the same just exit

    lda $7f91           ;get the drive select latch copy
    cmp #$07            ;compare it with all drives selected
    bcs l_ec08          ;if >= $07 go do disk error $14, no disk selected

    ora #$08            ;mask xxxx 1xxx, set ?? bit
    sta drive_sel       ;save the drive select latch

    lda #$23            ;set the delay count, 35ms
    jsr l_ec55          ;delay for A * 1000 cycles

    lda fdc_cmdst       ;get the WD1793 status register
    and #%10000000      ;mask x000 0000, drive not ready
    bne l_ec05          ;if the drive is not ready go do disk error $13, drive
                        ;   not ready
l_ebcd:
    rts


l_ebce:
;seek to track with retries ??
;
    lda #$03            ;set the retry count
    sta $7f8c           ;save the retry count
l_ebd3:
    lda $7f92           ;get the WD1793 track number
    cmp #$4d            ;compare it with max + 1
    bpl l_ebff          ;if > max go do disk error $15

    sta fdc_data        ;write the target track to the WD1793 data register
    lda #%10011000      ;mask x00x x000,
                        ;     x          drive not ready
                        ;        x       record not found
                        ;          x     CRC error
    sta $7f90           ;save the WD1793 status byte mask

    lda #$16            ;set seek command, verify track, 20ms step rate
    jsr l_ec0d          ;wait for WD1793 not busy and do command A
    bne l_ebf2          ;go handle any returned error

    lda $7f92           ;get the WD1793 track number
    cmp fdc_track       ;compare it with the WD1793 track register
    bne l_ebf2          ;go handle any difference

    rts

    ; there was an error or the track numbers differ

l_ebf2:
    lda #$02            ;set restore command, 20ms step rate
    jsr l_ec0d          ;wait for WD1793 not busy and do command A

    dec $7f8c           ;decrement the retry count
    bne l_ebd3          ;if not all done go try again

    ; else do disk error $10

    lda #$10            ;set error $10
    !byte $2c           ;makes next line BIT $xxxx

    ; do disk error $15

l_ebff:
    lda #$15            ;set error $15
    !byte $2c           ;makes next line BIT $xxxx

    ; do disk error $17

l_ec02:
    lda #$17            ;set error $17
    !byte $2c           ;makes next line BIT $xxxx

    ; do disk error $13, drive not ready

l_ec05:
    lda #$13            ;set error $13
    !byte $2c           ;makes next line BIT $xxxx

    ; do disk error $14

l_ec08:
    lda #$14            ;set error $14
    jmp l_ec96          ;do "DISK ERROR" message and ??


l_ec0d:
; wait for WD1793 not busy and do command A
;
    jsr l_ec1e          ;wait for WD1793 not busy
    bcs l_ec02          ;if counted out go do disk error $17

    sta $7f95           ;save the WD1793 command register copy
    sta fdc_cmdst       ;save the WD1793 command

    jsr l_ec53          ;delay for $C6 * ?? cycles
    jmp l_ecd0          ;wait for WD1793 not busy mask the status and return


l_ec1e:
; wait for WD1793 not busy
;
    pha                 ;save A
    txa                 ;copy X
    pha                 ;save X
    tya                 ;copy Y
    pha                 ;save Y

    ldy #$20            ;set the outer loop count
l_ec25:
    ldx #$ff            ;set the inner loop count
l_ec27:
    lda fdc_cmdst       ;get the WD1793 status register
    and #%00000001      ;mask 0000 000x, busy
    beq l_ec4c          ;if not busy go return not counted out

    lda #$23            ;set the wait count
    sta $7f8d           ;save the wait count
l_ec33:
    dec $7f8d           ;decrement the wait count
    bne l_ec33          ;loop if more to do

    dex                 ;decrement the inner loop count
    bne l_ec27          ;loop if more to do

    dey                 ;decrement the outer loop count
    bne l_ec25          ;loop if more to do

    lda #$d8            ;set force interrupt command, immediate interrupt
    sta $7f95           ;save the WD1793 command register copy
    sta fdc_cmdst       ;save the WD1793 command
    jsr l_ec53          ;delay for $C6 * ?? cycles
    sec                 ;flag counted out
    bcs l_ec4d          ;return the flag, branch always

l_ec4c:
    clc                 ;flag not counted out
l_ec4d:
    pla                 ;pull Y
    tay                 ;restore Y
    pla                 ;pull X
    tax                 ;restore X
    pla                 ;restore A
    rts


l_ec53:
; delay for $C6 * ?? cycles
;
    lda #$01            ;set the outer loop count


l_ec55:
; delay for A * $C6 * ?? cycles
;
    sta $7f8d           ;save the outer loop count
    stx $7f8e           ;save X
l_ec5b:
    ldx #$c6            ;set the inner loop count
l_ec5d:
    dex                 ;decrement the inner loop count
    bne l_ec5d          ;loop if more to do

    dec $7f8d           ;decrement the outer loop count
    bne l_ec5b          ;loop if more to do

    ldx $7f8e           ;restore X
    rts


l_ec69:
; increment pointers to the next sector ??
;
    lda l_b7            ;get the memory pointer low byte
    clc                 ;clear carry for add
    adc #$80            ;add the sector byte count
    sta l_b7            ;save the memory pointer low byte
    bcc l_ec74          ;if no carry skip the highbyte increment

    inc l_b8            ;else increment the memory pointer high byte
l_ec74:
    ldx $7f93           ;get the WD1793 sector number
    inx                 ;increment the sector number
    cpx #$1b            ;compare it with max + 1
    bmi l_ec89          ;if < max + 1 just exit

    ldx $7f92           ;get the WD1793 track number
    inx                 ;increment the track number
    stx $7f92           ;save the WD1793 track number
    cpx #$4d            ;compare it with max + 1
    bpl l_ec94          ;if > max go do disk error $11

    ldx #$01
l_ec89:
    stx $7f93           ;save the WD1793 sector number
    clc                 ;flag ok
    rts


l_ec8e:
;TODO ??
;
    jsr l_ec96          ;do "DISK ERROR" message and ??
    jmp l_eb5e


l_ec94:
;TODO do disk error $11
;
    lda #$11


l_ec96:
; do "DISK ERROR" message and ??
;
    pha                 ;save A
    tya                 ;copy Y
    pha                 ;save Y

    ; do "DISK ERROR" message

    lda #<disk_error    ;set the message pointer low byte
    ldy #>disk_error    ;set the message pointer high byte
    jsr puts            ;message out

    pla                 ;pull Y
    tay                 ;restore Y
    pla                 ;restore A

    jsr l_eb7f          ;output [SPACE] <A> as a two digit hex Byte

    ldx #$00            ;clear the index
l_eca8:
    lda $7f90,x
    jsr l_eb7f          ;output [SPACE] <A> as a two digit hex Byte
    inx                 ;increment the index
    cpx #$07            ;compare it with max + 1
    bmi l_eca8          ;loop if more to do

    lda #$02            ;set restore command, 20ms step rate
    sta fdc_cmdst       ;save the WD1793 command

    cli                 ;enable interrupts
    jsr l_eb0b          ;deselect the drives and stop the motors ??
    sec
l_ecbd:
    lda #$ff
    rts


l_ecc0:
; write a WD1793 command and wait a bit
;
    sta $7f95           ;save the WD1793 command register copy
    sta fdc_cmdst       ;save the WD1793 command

    ldy #$00            ;clear Y
    ldx #$12            ;set the delay count
l_ecca:
    dex                 ;decrement the delay count
    bne l_ecca          ;loop if more to do

    ldx #$80            ;set the byte count ??
    rts


l_ecd0:
; wait for WD1793 not busy and mask the status
;
    jsr l_ec1e          ;wait for WD1793 not busy
    bcs l_ecbd          ;if counted out go return $FF

    lda fdc_cmdst       ;get the WD1793 status register
    sta $7f94           ;save the WD1793 status register copy
    and $7f90           ;AND it with the WD1793 status byte mask
    rts


l_ecdf:
; read one sector to memory ??
;
    lda #$01            ;set the sector count
    sta $7f96           ;save the sector count


read_sectors:
; read <n> sector(s) to memory ??
;
    jsr l_eba0
    bne l_ed38          ;if there was any error just exit

l_ece9:
    jsr l_ebce          ;seek to track with retries ??
    bne l_ed38

l_ecee:
    lda #$0a
    sta $7f8c
l_ecf3:
    lda #%11011110      ;mask xx0x xxx0,
                        ;     x          drive not ready
                        ;      x         write protected
                        ;        x       record not found
                        ;          x     CRC error
                        ;           x    lost data
                        ;            x   data request
    sta $7f90           ;save the WD1793 status byte mask

    lda $7f93           ;get the WD1793 sector number
    beq l_ed33          ;if zero go do disk error $40

    sta fdc_sector      ;save the WD1793 sector register

    lda #$88            ;set read single sector command, side 1
    jsr l_ecc0          ;write a WD1793 command and wait a bit
l_ed05:
    lda fdc_cmdst       ;get the WD1793 status register
    and #%00010110      ;mask 000x 0xx0,
                        ;        x       record not found
                        ;           x    lost data
                        ;            x   data request
    beq l_ed05          ;if no data request or error go try again

    lda fdc_data        ;read the WD1793 data register
    sta (l_b7),y        ;save the byte to memory
    iny                 ;increment the index
    dex                 ;decrement the count
    bne l_ed05          ;loop if more to do

    jsr l_ecd0          ;wait for WD1793 not busy and mask the status
    bne l_ed2e          ;if any bits set go ??

    dec $7f96           ;deccrement the sector count
    beq l_ed38          ;if all done just exit

    jsr l_ec69          ;increment pointers to the next sector ??
    bcs l_ed38          ;if error just exit

    lda $7f92           ;get the WD1793 track number
    cmp fdc_track       ;WD1793 track register
    beq l_ecee

    bne l_ece9

l_ed2e:
    dec $7f8c
    bne l_ecf3

    ; do disk error $40

l_ed33:
    lda #$40
    jmp l_ec96          ;do "DISK ERROR" message and ??

    ; no error exit

l_ed38:
    cli                 ;enable interrupts
    rts


l_ed3a:
; write one sector to disk ??
;
    lda #$01            ;set a single sector
    sta $7f96           ;save the sector count


write_sectors:
; write <n> sector(s) to disk ??
;
    jsr l_eba0
    bne l_ed38

l_ed44:
    jsr l_ebce          ;seek to track with retries ??
    bne l_ed38

    lda fdc_cmdst       ;get the WD1793 status register
    and #%01000000      ;mask 0x00 0000, write protected
    bne do_protected    ;if write protected go do "PROTECTED!" message and exit

l_ed50:
    lda #$0a
    sta $7f8c
l_ed55:
    lda #%11111100      ;mask xxxx xx00,
                        ;     x          drive not ready
                        ;      x         write protected
                        ;       x        write fault
                        ;        x       record not found
                        ;          x     CRC error
                        ;           x    lost data
    sta $7f90           ;save the WD1793 status byte mask

    lda $7f93           ;get the WD1793 sector number
    beq l_eda2          ;if zero go do disk error $50

    sta fdc_sector      ;save the WD1793 sector register
    lda #$a8            ;set write single sector command, side 1
    jsr l_ecc0          ;write a WD1793 command and wait a bit
l_ed67:
    lda fdc_cmdst       ;get the WD1793 status register
    and #%11010110      ;mask xx0x 0xx0,
                        ;     x          drive not ready
                        ;      x         write protected
                        ;        x       record not found
                        ;           x    lost data
                        ;            x   data request
    beq l_ed67          ;if no flags set go wait some more

    cmp #$02            ;compare it with data request
    beq l_ed7b          ;if data request go send the next byte

    bne l_ed84          ;else go handle everything else, branch always

l_ed74:
    lda fdc_cmdst       ;get the WD1793 status register
    and #%10010110      ;mask x00x 0xx0,
                        ;     x          drive not ready
                        ;        x       record not found
                        ;           x    lost data
                        ;            x   data request
    beq l_ed74          ;if no flags set go wait some more

l_ed7b:
    lda (l_b7),y        ;get a byte from memory
    sta fdc_data        ;write the WD1793 data register
    iny                 ;inccrement the index
    dex                 ;decrement the byte count
    bne l_ed74          ;loop if more to do

l_ed84:
    jsr l_ecd0          ;wait for WD1793 not busy and mask the status
    bne l_ed9d          ;if any bits set go ??

    dec $7f96           ;deccrement the sector count
    beq l_ed38          ;if all done just exit

    jsr l_ec69          ;increment pointers to the next sector ??
    bcs l_ed38          ;if error just exit

    lda $7f92           ;get the WD1793 track number
    cmp fdc_track       ;WD1793 track register
    beq l_ed50

    bne l_ed44

l_ed9d:
    dec $7f8c
    bne l_ed55

    ; do disk error $50

l_eda2:
    lda #$50            ;set disk error $50
    jmp l_ec96          ;do "DISK ERROR" message and ??


do_protected:
; do "PROTECTED!" message
;
    lda #<protected     ;set the message pointer low byte
    ldy #>protected     ;set the message pointer high byte
    jsr puts            ;message out
    clc
    bcc l_eda2          ;do disk error $50, branch always


protected:
    !text $0d,"PROTECTED!",$00


l_edbd:
;TODO ??
;
    jsr chrget          ;get the next BASIC byte
    cmp #$22
    php
    bne l_edd3

    jsr chrget          ;get the next BASIC byte
    lda txtptr
    sta $24
    lda txtptr+1
    sta $25
    jmp l_edea

l_edd3:
    jsr ptrget          ;find variable
    bit $07
    bmi l_eddf

    lda #$03


l_eddc:
;TODO ??
;
    jmp l_ec8e

;***********************************************************************************;
;
; get a filename from a string

l_eddf:
    ldy #$01            ;set the index to the string pointer low byte
    lda ($44),y         ;get the string pointer low byte
    sta $24             ;save the filename pointer low byte
    iny                 ;increment the index to the string pointer high byte
    lda ($44),y         ;get the string pointer high byte
    sta $25             ;save the filename pointer high byte

; get a filename
;
; unless I'm mistaken a filename must include a ":" character and the drive number
; at the end. no check is done on the drive number character so any charater will
; be taken as a valid drive number

l_edea:
    ldy #$00            ;clear the index
l_edec:
    lda ($24),y         ;get a filename character
    cmp #$3a            ;compare it with ":"
    beq l_ee01          ;if it is ":" go get a drive number

    cpy #$06            ;compare the index with max + 1
    bcc l_edfb          ;if not max + 1 continue

; do disk error $04, bad filename

l_edf6:
    lda #$04            ;set disk error $04, bad filename
    jmp l_eddc          ;do disk error and restore the stack

l_edfb:
    sta $7fa0,y         ;save a filename character
    iny                 ;increment the index
    bpl l_edec          ;go get another filename character, branch always

l_ee01:
    tya                 ;copy the index ..
    tax                 ;.. to X

; pad the rest of the filename with spaces

    lda #$20            ;set [SPACE]
l_ee05:
    cpx #$06            ;compare the filename index with max + 1
    bcs l_ee0f          ;if done go get the drive number

    sta $7fa0,x         ;save a [SPACE] to the filename
    inx                 ;increment the index
    bpl l_ee05          ;go try another space, branch always

; get the drive number. there seems to be no checking for drive 3 which may break things

l_ee0f:
    iny                 ;increment the index to the drive character
    lda ($24),y         ;get the drive character
    and #$03            ;mask the drive
    tax                 ;copy it to the index
    lda l_ea2f,x        ;get the drive select byte
    sta $7fb1           ;save the drive select byte

    plp                 ;restore the open quote compare status
    bne l_ee32          ;if it wasn't an immediate string just exit

; else it was an immediate string so move the get BASIC byte pointer past it

    tya                 ;copy the index
    clc                 ;clear carry for add
    adc txtptr          ;add the BASIC byte pointer low byte
    sta txtptr          ;save the BASIC byte pointer low byte
    bcc l_ee28          ;if no carry skip the high byte increment

    inc txtptr+1        ;else increment the BASIC byte pointer high byte
l_ee28:
    jsr chrget          ;get the next BASIC byte
    cmp #$22            ;compare it with a close quote character
    bne l_edf6          ;if it's not a close quote go do disk error $04, bad
                        ;   filename

    jsr chrget          ;get the next BASIC byte
l_ee32:
    rts


find_file:
; search for filename in the directory
;
; returns $22/23 pointing to the entry and the returned status in X
; the directory starts on track 0, sector 1 and runs to track 0, sector 8
;
; the first file entry in the directory is at $10 in the first sector
;
; a directory entry consists of ..
;
; $00-$05   byte  filename
; $06-$07   word  file length
; $08-$09   word  load address
; $0A       byte  file type
; $0B       byte  ??
; $0C       byte  file track number
; $0D       byte  file sector number
; $0E       byte  file sector count
; $0F       byte  ??
;
    lda $7fb1           ;get the drive select byte
    sta $7f91           ;save the drive select latch copy

    ldy #$00            ;set track zero
    sty $7f92           ;save the WD1793 track number

    iny                 ;set sector one
    sty $7f93           ;save the WD1793 sector number

    lda #$00            ;set the memory pointer low byte
    sta l_b7            ;save the memory pointer low byte
    lda #$7f            ;set the memory pointer high byte
    sta l_b8            ;save the memory pointer high byte
    sta $23             ;set the search pointer high byte

    jsr l_ecdf          ;read one sector to memory
    bne l_ee94          ;if there was an error just exit

; there was no error

    lda $7f09
    sta $56
    lda $7f0a
    sta $57

; there was no error

    lda #$10            ; set the index to the first directory entry
l_ee5d:
    sta $22             ; set the directory search pointer low byte
l_ee5f:
    ldy #$00            ; clear the index
    lda ($22),y         ; get a character from the directory
    cmp #$ff            ; compare it with the end marker
    beq l_ee95          ; if end of directory go do the not found exit


l_ee67:
    cmp $7fa0,y         ; compare it with a filename character
    bne l_ee76          ; if not a match go try the next directory entry

    iny                 ; increment the filename index
    cpy #$06            ; compare it with max + 1
    bpl l_ee92          ; if all compared go do the file found exit

    lda ($22),y         ; else get the next character from the directory
    jmp l_ee67          ; go compare the characters

; no match so try the next entry

l_ee76:
    lda $22             ; get the directory search pointer low byte
    clc                 ; clear carry for add
    adc #$10            ; add the offset to the next directory entry
    sta $22             ; save the directory search pointer low byte
    bpl l_ee5f          ; if not past the end of the sector go test the next entry

; else this sector is all done, get the next directory sector

    inc $7f93           ;increment the WD1793 sector number
    lda $7f93           ;get the WD1793 sector number
    cmp #$09            ; compare it with max + 1
    bpl l_ee95          ; if > max go do the not found exit

    jsr l_ecdf          ; read one sector to memory
    bne l_ee94          ; if there was an error just exit

    lda #$00            ; set the index to the next directory entry
    beq l_ee5d          ; continue the directory search, branch always

; found the file exit

l_ee92:
    lda #$00            ; flag found
l_ee94:
    rts

; not found exit

l_ee95:
    lda #$7f            ; flag not found
    rts


l_ee98:
;!LOAD
;
    jsr perform_load          ; perform !LOAD
    jmp l_eb5e          ; restore the top 32 bytes of the stack page and return EOT


perform_load:
;perform !LOAD
;
    jsr find_file          ; search for filename in the directory
    tax                 ; copy the returned value
    bne l_eee6          ; if not found go do "??????" message

    ldy #$0a            ; set the index to the file type
    lda ($22),y         ; get the file type
    cmp #$03            ; compare it with ?? type
    bmi l_eee6          ; if less than ?? go do "??????" message

    bne l_eebe          ; if not type $03 skip setting the end of program

; the file is type $03

    ldy #$06            ; set the index to the file length low byte
    lda ($22),y         ; get the file length low byte
    clc                 ; clear carry for add
    adc $28             ; add BASIC start of program low byte
    sta $2a             ; save BASIC start of variables low byte
    iny                 ; increment the index to the file length high byte
    lda ($22),y         ; get the file length high byte
    adc $29             ; add BASIC start of program high byte
    sta $2b             ; save BASIC start of variables high byte
l_eebe:
    ldy #$08
    lda ($22),y
    sta l_b7            ;save the memory pointer low byte
    iny
    lda ($22),y
    sta l_b8            ;save the memory pointer high byte
    ldy #$0c
    lda ($22),y
    sta $7f92           ;save the WD1793 track number
    iny
    lda ($22),y
    sta $7f93           ;save the WD1793 sector number
    iny
    lda ($22),y
    sta $7f96           ;save the sector count
    jsr read_sectors    ;read <n> sector(s) to memory
    bne l_eef0          ;if there was an error go flag it and exit

    ldx #$00            ;flag no error
l_eee3:
    jmp l_eb0b          ;stop the disk and return

; output "??????"

l_eee6:
    ldx #$06            ;set the "?" count
    lda #$3f            ;set "?"
l_eeea:
    jsr chrout          ;do character out
    dex                 ;decrement the count
    bne l_eeea          ;loop if more to do

; there was a load error

l_eef0:
    ldx #$ff            ;flag a load error
    bne l_eee3          ;go deselect the drives and exit, branch always


addr_prompt:
    !text $0d,"ADDR?",$00


l_eefb:
; get a hex address into $66/67
;
    pha                 ;save A
    tya                 ;copy Y
    pha                 ;save Y

    lda #<addr_prompt   ;set the message pointer low byte
    ldy #>addr_prompt   ;set the message pointer high byte
    jsr puts            ;message out

    pla                 ;pull Y
    tay                 ;restore Y
    pla                 ;restore A
l_ef08:
    jsr l_ef1b          ;get and evaluate a hex byte
    bcs l_ef08          ;if error get another byte

    sta $67             ;save the address high byte
    jsr l_ef1b          ;get and evaluate a hex byte
    sta $66             ;save the address low byte
    bcc l_ef2e          ;if no error just exit

    jsr l_ef2f          ;output "??" and shift the cursor left
    bcs l_ef08          ;go get another word


l_ef1b:
; get and evaluate a hex byte
;
    jsr l_ef41          ;get and evaluate a hex character


l_ef1e:
; get and evaluate a hex byte second character
;
    bcs l_ef32          ;if not hex output "?" and shift the cursor left

    asl                 ;shift the ..
    asl                 ;.. low nibble ..
    asl                 ;.. to the ..
    asl                 ;.. high nibble
    sta $26             ;save the high nibble
    jsr l_ef41          ;get and evaluate a hex character
    bcs l_ef2f          ;if there was an error output "??" and cursor left

    ora $26             ;OR it with the high nibble
    clc                 ;flag ok
l_ef2e:
    rts


l_ef2f:
; output "??" and shift the cursor left
;
    jsr l_ef32          ;output "?" and shift the cursor left


l_ef32:
;output "?" and shift the cursor left
;
    lda #$3f            ;set "?"
    jsr chrout          ;do character out
    lda #$9d            ;set cursor left
    jsr chrout          ;do character out
    jsr chrout          ;do character out
l_ef3f:
    sec                 ;flag error
    rts


l_ef41:
; get and evaluate a hex character
;
    jsr l_ef59          ;get a character and test for {STOP}


l_ef44:
; test and evaluate a hex digit
;
    CMP #'0'            ;compare the character with "0"
    bcc l_ef3f          ;if < "0" go return non hex

    CMP #'9'+1          ;compare the character with "9"+1
    bcc l_ef54          ;if < "9"+1 go evaluate the hex digit

    CMP #'A'            ;compare the character with "A"
    bcc l_ef3f          ;if < "A" go return non hex

    CMP #'F'+1          ;compare the character with "F"+1
    bcs l_ef3f          ;if >= "F"+1 go return non hex

    ; evaluate the hex digit

l_ef54:
    jsr l_d78d          ;evaluate a hex digit
    clc                 ;flag a hex digit
l_ef58:
    rts


l_ef59:
; get a character and test for {STOP}
;
    txa                 ;copy X
    pha                 ;save X
    tya                 ;copy Y
    pha                 ;save Y

    lda #$e6            ;set the cursor character
    jsr chrout          ;do character out
    lda #$9d            ;set cursor left
    jsr chrout          ;do character out

    jsr l_ef7b          ;wait for and echo a character
    sta $7f88           ;save the charater

    pla                 ;pull Y
    tay                 ;restore Y
    pla                 ;pull X
    tax                 ;restore X

    lda $7f88           ;restore the charater
    cmp #$03            ;compare it with {STOP}
    bne l_ef58          ;if not {STOP} just exit

    jmp $7a00           ;else go do {STOP}


l_ef7b:
; wait for and echo a character
;
    jsr getin          ;do character in
    beq l_ef7b          ;if no character just wait

    jmp chrout          ;do character out


edit_memory:
;display/edit memory
;
    jsr l_eefb          ;get a hex address into $66   /67
l_ef86:
    lda #$0d            ;set [CR]
    jsr chrout          ;do character out

    lda $67             ;get the address high byte
    jsr l_eb7f          ;output [SPACE] <A> as a two digit hex Byte
    lda $66             ;get the address low byte
    jsr l_eb84          ;output A as a two digit hex Byte

    ldy #$00            ;clear the index
l_ef97:
    lda ($66),y         ;get a byte from memory
    jsr l_eb7f          ;output [SPACE] <A> as a two digit hex Byte
    iny                 ;increment the index
    cpy #$08            ;compare it with max + 1
    bmi l_ef97          ;loop if more to do

    lda #$0d            ;set [CR]
    jsr chrout          ;do character out

; output six spaces

    ldx #$06            ;set the [SPACE] count
l_efa8:
    jsr l_eb7a          ;output a [SPACE] character
    dex                 ;decrement the [SPACE] count
    bne l_efa8          ;loop if more to do

l_efae:
    stx $27             ;save the line index
    jsr l_ef59          ;get a character and test for {STOP}
    cmp #$0d            ;compare the character with [CR]
    beq edit_memory   ;if [CR] go get another hex address

    cmp #$20            ;compare it with [SPACE]
    bne l_efc0          ;if not [SPACE] go evaluate a hex digit

; the character was [SPACE]

    jsr l_eb7a          ; output another [SPACE] character
    bne l_efd0          ;go increment the address, branch always

; evaluate a hex digit

l_efc0:
    jsr l_ef44          ;test and evaluate a hex digit
    jsr l_ef1e          ;get and evaluate a hex byte second character
    bcs l_efae          ;if error go retry this byte

    ldy #$00            ;clear the index
    sta ($66),y         ;save the byte
    cmp ($66),y         ;compare the byte with the saved copy
    bne l_efe2          ;if not the same go do "??" to show it didn't save

; the byte saved or [SPACE] was returned

l_efd0:
    jsr l_eb7a          ;output a [SPACE] character
    inc $66             ;increment the memory address low byte
    bne l_efd9          ;if no rollover skip the high byte increment

    inc $67             ;else increment the memory address high byte
l_efd9:
    ldx $27             ;restore the line index
    inx                 ;increment it
    cpx #$08            ;compare it with max + 1
    bmi l_efae          ;if not there yet go do another byte

    bpl l_ef86          ;else go display a new line, branch always

; the byte didn't save to memory correctly

l_efe2:
    jsr l_ef2f          ;output "??" and shift the cursor left
    bcs l_ef86          ;go display memory from address, branch always


puts:
; message out
;
    sta $6c             ;save the message pointer low byte
    sty $6d             ;save the message pointer high byte
    ldy #$ff            ;set -1 for pre increment
puts_loop:
    iny                 ;increment the index
    lda ($6c),y         ;get the next character
    beq puts_done       ;if it's the end marker just exit

    jsr chrout          ;do character out
    clc                 ;clear carry
    bcc puts_loop       ;go do the next character, branch always
puts_done:
    rts

    ; unused
    !byte $68,$07,$01,$2b,$ff,$09,$5e
