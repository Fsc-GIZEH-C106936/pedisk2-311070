L7A05 = $7A05
L7D97 = $7D97
LFFD2 = $FFD2

    *=$7c00

    jmp L7D03

    !text "A-MACROASM/EDIT",$21
    !text "N-RENAME A FILE",$25
    !byte $42,$2d,$21,$4f,$2d,$25,$43,$2d,$21
    !text "P-PRINT DISK DIRECT",$25
    !text "D-DUMP DISK OR MEM",$21
    !text $51,$2d,$25,$45,$2d,$21
    !text "R-RE-ENTER BASIC",$25
    !text $46,$2d,$21
    !text "S-SAVE A PROGRAM",$25
    !text "G-GO TO MEMORY",$21
    !byte $54,$2d,$25
    !text "H-HELP",$21
    !text "U-UTILITY DISK MENU",$25
    !byte $49,$2d,$21,$56,$2d,$25,$4a,$2d,$21,$57,$2d,$25
    !text "K-KILL A FILE",$21
    !text "X-EXECUTE DISK FILE",$25
    !text "L-LOAD DISK PROGRAM",$21
    !byte $59,$2d,$25
    !text "M-MEMORY ALTER",$21
    !byte $5a,$2d,$25,$ff

L7D03:
    lda #$03
    sta $54
    lda #$7C
    sta $55
    lda #$93
    jsr LFFD2
    ldy #$00
L7D12:
    ldx #$14
L7D14:
    lda ($54),y
    inc $54
    bne L7D1C
    inc $55
L7D1C:
    cmp #$21
    beq L7D2E
    cmp #$25
    beq L7D38
    cmp #$FF
    beq L7D40
    jsr LFFD2
    dex
    bne L7D14
L7D2E:
    lda #$20
L7D30:
    jsr LFFD2
    dex
    bne L7D30
    beq L7D12
L7D38:
    lda #$0D
    jsr LFFD2
    jmp L7D12
L7D40:
    lda #$0D
    jsr LFFD2
    jsr LFFD2
    jmp L7A05

    eor $20
    jsr $5954
    bvc $7D97
    jsr $5254
    !byte $4B
    jsr $4353
    !byte $54
    !byte $52
    jsr $5323
    !byte $43
    !byte $54
    !byte $52
    !byte $53
    brk
    !byte $53
    eor $51
    brk
    eor #$4E
    !byte $44
    brk
    eor #$53
    eor $4200
    eor ($53,x)
    brk
    eor ($53,x)
    eor $4C00
    !byte $44
    jsr $5400
    cli
    !byte $54
    brk
    !byte $4F
