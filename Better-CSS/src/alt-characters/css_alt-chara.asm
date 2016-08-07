//bass-n64
//========================================
//-----Hack Info
//========================================

// requires
// "LIB/N64defs.inc", bass macros, ssbFuncs, cssFuncs

//grab size
evaluate assembledSize(origin())

scope custom_pallets: {
  align(8)
  polygon:
    dw 0x0000, 0x1009, 0x3013, 0x501F
    dw 0x6025, 0x78EB, 0xFFFF, 0xFFFF
    align(8)
  polygon_cpu:
    dw 0x0000, 0x6B1B, 0x7B61, 0x8BA5
    dw 0x93E9, 0xA46D, 0xFFFF, 0xFFFF
    align(8)
  gdk:
    dw 0x0000, 0x3905, 0x4987, 0x7249
    dw 0x9B0D, 0xCCCD, 0xFFFF, 0xFFFF
    align(8)
  gdk_cpu:
    dw 0x0000, 0x6B17, 0x7B59, 0x941B
    dw 0xAC9F, 0xCDA1, 0xFFFF, 0xFFFF
    align(8)
  mm:
    dw 0x0000, 0x4211, 0x739D, 0xA529
    dw 0xC631, 0xEF7B, 0xFFFF, 0xFFFF
    align(8)
  mm_cpu:
    dw 0x0000, 0x39CF, 0x635B, 0x94A5
    dw 0xADAD, 0xD6B5, 0xFFFF, 0xFFFF
    align(8)
  array:
    dd polygon, polygon_cpu, gdk, gdk_cpu, mm, mm_cpu
    align(4)
}

// the state for each player 0-3
// 1 byte each
alt_char_state: {
  db 0, 0, 0, 0
  align(4)
}
// enum of alt character values
include "alt-char-state-enum.inc"

// FGM Values for a0 for playFGM call
// Regular Character name will just use the built-in table
scope FGM {
  constant MM(0x1CE)
  constant GDK(0x1E9)
  constant FPT(0x1E2)
}

// Use D-PAD to change alt character state
scope dpad_alt_char_state: {
  // return a {StackSize} for stack size in bytes
  nonLeafStackSize(4)         //Standard MIPS Non-Leaf + 4 registers

  replacement:
  // replacement instructions from hooking into this routine
  sw    t8, 0x0024(sp)        // Save Pointer to Button State
  check_dpad_state:
  // if there are no d-pad presses, we don't need to do anything
  lhu   t0, 0x0002(t8)        // unique press button state
  andi  t0, t0, 0x0F00        // Check for any D-PAD button
  beq   t0, r0, return        // if no d-pad press, exit
  nop

  prologue:
  // save arguments b/c they might be important for actual code
  sw    a0, 0x0000(sp)
  sw    a1, 0x0004(sp)        // Note: This is player index
  sw    a2, 0x0008(sp)
  sw    a3, 0x000C(sp)
  ori   at, sp, 0             // save old sp in at to move to s8/fp

  subiu sp, sp, {StackSize}   // get new stack space
  sw    ra, 0x0014(sp)
  sw    s0, 0x0018(sp)
  sw    s1, 0x001C(sp)
  sw    s8, 0x0020(sp)
  sw    s2, 0x0024(sp)
  or    fp, r0, at            // fp is s8

  check_char_selected:
  // start multiplying the player index by 0xBC
  ori   at, r0, 0xBC
  multu a1, at                // Player Index * BC
  lui   s0, 0x8013
  ori   s0, s0, 0xBA88
  mflo  at                    // Grab Player Index * 0xBC
  addu  s0, at, s0            // full player struct pointer
  lw    at, 0x0080(s0)        // character selected?
  beq   at, r0, epilogue      // if not selected, go to epilogue
  lw    s1, 0x0048(s0)        // BD; grab character index

  // D-PAD Checks. D-PAD Left or Right
  dpad_rl:
  // return character to normal
  andi  at, t0, 0x0300        // Left | Right 0x200 | 0x100
  beq   at, r0, dpad_up       // if (l or r) continue

  lui   a0, 0x8013            // branch delay
  ori   a0, a0, 0xB800        // load character name FGM base pointer
  sll   at, s1, 1             // character index * 2
  addu  a0, a0, at            // offset pointer by character
  lhu   a0, 0x0000(a0)        // load character name FGM value
  beq   r0, r0, update_state
  ori   t1, r0, AltState.NONE

  dpad_up:
  // polygon version
  andi  at, t0, 0x0800
  beq   at, r0, dpad_down     // if not UP, go check DOWN

  ori   a0, r0, FGM.FPT       // BD; FGM = "FIGHT POLYGON TEAM"
  beq   r0, r0, update_state  // set alt-char-state to polygon
  ori   t1, r0, AltState.POLYGON

  // don't need to check against 0x0400, as it has to be this
  // set Metal Mario or Giant DK if applicable
  dpad_down: {
    MM_check:
    bne   s1, r0, DK_check      // if not Mario, check for DK

    ori   a0, r0, FGM.MM        // BD; set FGM to  "METAL MARIO!"
    beq   r0, r0, update_state
    ori   t1, r0, AltState.MM

    DK_check:
    ori   at, r0, 0x0002
    bne   s1, at, epilogue    // if not DK, don't change anything

    ori   a0, r0, FGM.GDK     // BD; set FGM to "Giant Donkey Kong"
    beq   r0, r0, update_state
    ori   t1, r0, AltState.GDK
  }

  update_state:
  // First, check if we need to update state...
  li    s2, alt_char_state    // Psuedo-I; load alt_char_state address
  addu  s2, s2, a1            // offset by player
  lbu   t2, 0x0000(s2)        // current alt_char_state
  beq   t1, t2, epilogue      // if current state = state to set
  nop                         // do nothing, else
  // play FGM to announce char state
  jal   fn.ssb.playFGM
  sb    t1, 0x0000(s2)        // set alt-char-state byte for this player

  // call pallet change routine
  lw    a0, 0x0018(s0)        // needed, unknown pointer from player struct
  // check for team mode
  // if it is team mode, don't use player index for a1
  // use a "specialized" team index for a1 [00: red team; 01: blue; 03 green]
  if_teams:
  lui   t1, 0x8014
  lw    t1, 0xBDA8(t1)         // team mode int (0 Off | 1 On)
  beqz  t1, endif_teams_else   // if (team mode){ ...
  lui   t1, 0x8013
  ori   t1, 0xB7D8                // teams_pallet_indicies.array
  lw    at, 0x0040(s0)            // current_team
  sll   at, at, 0x2               // current_team * 4
  addu  t1, at, t1                // a1 = t_p_i[current_team]
  b     end_else                  //
  lw    a1, 0x0000(t1)        // } else {

  endif_teams_else:
  lw    a1, 0x0004(fp)        // reload player index
  end_else:                   // }
  jal   fn.css.updatePlayerPanelPallet
  lw    a2, 0x0084(s0)        // MAN | CPU | Closed: lw a2, 0x84(s0)

  epilogue:
  lw    ra, 0x0014(sp)
  lw    s0, 0x0018(sp)
  lw    s1, 0x001C(sp)
  lw    s8, 0x0020(sp)
  lw    s2, 0x0024(sp)
  addiu sp, sp, {StackSize}   // free our stack

  lw    a0, 0x0000(sp)        // reload a0-3
  lw    a1, 0x0004(sp)
  lw    a2, 0x0008(sp)
  lw    a3, 0x000C(sp)

  return:
  jr    ra
  lw    t8, 0x0024(sp)        // Restore t8 for original code
}


// void resetAltState( uint player-index )
// a0 : player index
//-------------------
// Register Map
//-------------------
// a0 : player index pinput]
//      -> pointer for update pallet
// a1 : player index
// a2 : MAN | CPU panel state

// t0 : alt_char_state base addr
//      -> + a0 to offset for player
//      then
//      *Player_Struct
// t1 : team mode checks

scope resetAltState: {
  nonLeafStackSize(0)         // Grab stack space for 0 saved regs
  prologue:
  subiu sp, sp, {StackSize}
  sw    ra, 0x0014(sp)

  reset_alt_state:
  ori   at, r0, 0xBC
  multu at, a0                // for player_struct pointer
  li    t0, alt_char_state
  ori   at, r0, AltState.NONE
  addu  t0, t0, a0            // pointer to current player alt_char_state
  sb    at, 0x0000(t0)        // set alt state to NONE

  pointer_player_struct:
  li    t0, 0x8013BA88
  mflo  at
  addu  t0, t0, at          // generate player_struct pointer

  update_pallet:
  scope if_teams {
    condition:
    lui   t1, 0x8014
    lw    t1, 0xBDA8(t1)        // team mode int (0 Off | 1 On)
    beqz  t1, endif_else        // if (team mode){ ...
    if_true: {
      lui   t1, 0x8013
      ori   t1, 0xB7D8           // teams_pallet_indicies.array
      lw    at, 0x0040(t0)       // current_team
      sll   at, at, 0x2          // current_team * 4
      addu  t1, at, t1           // a1 = t_p_i[current_team]
      b     endelse              //
      lw    a1, 0x0000(t1)      // } else {
    }
    endif_else: {
      or    a1, r0, a0          // move player index into a1
    }
    endelse:                   // }
  }
  lw    a0, 0x0018(t0)      // pointer to pallet image
  jal   fn.css.updatePlayerPanelPallet
  lw    a2, 0x0084(t0)      // MAN | CPU | Closed: lw a2, 0x84(s0)

  epilogue:
  lw    ra, 0x0014(sp)
  jr    ra
  addiu sp, sp, {StackSize}
}

scope bButtonResetState: {
  nonLeafStackSize(1)         // Grab space for 0 saved reg on stack

  prologue:
  ori   at, r0, 0xBC
  multu a0, at
  sw    a0, 0x0000(sp)
  subiu sp, sp, {StackSize}
  sw    ra, 0x0014(sp)
  //replacement insructions to generate *Player_Struct
  li    t0, 0x8013BA88
  mflo  at
  addu  t0, at, t0

  reset_state:
  jal   CSS.DMA.resetAltState   // a0 is already player index
  sw    t0, 0x0018(sp)      // store pointer now; grab in epilogue

  epilogue:
  lw    v0, 0x0018(sp)      // put *Player_Struct in v0, as it's expected there
  lw    ra, 0x0014(sp)
  addiu sp, sp, {StackSize}
  jr    ra
  lw    a0, 0x0000(sp)      // a0 is expected to be unchanged
}

// void closePanelResetState( uint player-index )
// a0 : player index
//-------------------
// Register Map
//-------------------
// a0 : player index [input]
//      -> soundfx for playFGM
scope closePanelResetState: {
  nonLeafStackSize(0)

  subiu sp, sp, {StackSize}
  sw    ra, 0x0014(sp)

  jal   CSS.DMA.resetAltState
  nop                     // a0 is already player index

  jal   fn.ssb.playFGM       // replacement for hook-in code
  ori   a0, r0, 0x00A7

  lw    ra, 0x0014(sp)
  jr    ra
  addiu sp, sp, {StackSize}
}

// void pickUpTokenResetState( uint player-index, uint token-player index )
// a0 : player index of cursor
// a1 : player index of token being picked up
//-------------------
// Register Map
//-------------------
// a0 : player index of token being picked up
// reset to input regs before calling original routine

scope pickUpTokenResetState: {
  // put into fn.css
  constant pickUpToken(0x8013760C)
  nonLeafStackSize(0)

  subiu sp, sp, {StackSize}
  sw    ra, 0x0014(sp)
  sw    a0, {StackSize}(sp)
  sw    a1, {StackSize}+4(sp)

  jal   CSS.DMA.resetAltState   // reset the state of the player
  or    a0, r0, a1              // whose token is being picked up

  lw    a0, {StackSize}(sp)
  jal   pickUpToken
  lw    a1, {StackSize}+4(sp)

  lw    ra, 0x0014(sp)
  jr    ra
  addiu sp, sp, {StackSize}
}

// void changeCharIndex()
//-------------------
// Register Map
//-------------------
// t0 : i (= player index)
// t1 : player_struct + i*0xBC
// t2 : is char selected?
//      then-> alt-char-state
// t3 : character index
scope changeCharIndex: {
  nonLeafStackSize(0)
  constant originalRoutine(0x8013A8B8)
  constant Player_BaseAddr(0x8013BA88)

  prologue:
  subiu sp, sp, {StackSize}
  sw    ra, 0x0014(sp)

  initialization:
  or    t0, r0, r0            // t0 = i = 0
  li    t1, Player_BaseAddr   // t1 = *player_struct
  do: {
    check_for_selected_char:
    lw    t2, 0x0088(t1)        // t2 = is char selected (bool 0 | 1)
    beqz  t2, end_if            // if ( char_selected ) {
    lw    t3, 0x0048(t1)        // BD; t3 = character index
    if_true: {
      switch_alt_state: {
        li    t2, alt_char_state
        addu  t2, t0, t2          //
        lbu   t2, 0x0000(t2)      // switch (alt-char-state){
        case_NONE:
        ori   at, r0, AltState.NONE
        beq   at, t2, end_switch

        case_polygon:
        ori   at, r0, AltState.POLYGON    // DB;
        bne   at, t2, case_MM
        addiu at, t3, 0x000E          // offset char-index by 0xE to get polygon version
        b     end_switch
        sw    at, 0x0048(t1)          // set player_struct char to polgyon index

        case_MM:
        ori   at, r0, AltState.MM
        bne   at, t2, case_GDK
        ori   at, r0, 0x000D          // load MM char index
        sw    at, 0x0048(t1)          // player_struct.char = 0xD
        b     end_switch
        sw    r0, 0x004C(t1)          // player_struct.color = 0; for non-glitched stock icons

        case_GDK:
        ori   at, r0, AltState.GDK
        bne   at, t2, update_conditions // do we need this check...?
        ori   at, r0, 0x001A
        b     end_switch
        sw    at, 0x0048(t1)          // player_struct.char = 0x1A (Giant DK)
      }
      end_switch:
    }
    end_if:
  }
  update_conditions:
  addiu t0, t0, 0x1       // i++

  while:
  sltiu at, t0, 0x4       // while ( i < 4 )
  bnez  at, do
  addiu t1, t1, 0xBC      // BD; player_struct + 1 player

  original_code:
  jal   originalRoutine   // afaik, this routine has no inputs or outputs`
  nop
  epilogue:
  lw    ra, 0x0014(sp)
  jr    ra
  addiu sp, sp, {StackSize}
}
// calculate the total size of the assembled routine
evaluate assembledSize(origin() - {assembledSize})

print "Included css_alt-chara.asm\n"
print "Compiled Size: {assembledSize} bytes\n\n"
