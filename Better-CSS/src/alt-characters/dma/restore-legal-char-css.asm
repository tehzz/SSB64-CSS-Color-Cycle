//bass-n64

// Jump only code (not a true routine)
// Turn an illegal, crashing character back into a legal one
// while also preserving the alt-char-state of the illegal character
//-------------------
// Register Map
//-------------------
// Inputs
// a1 : Panel State [0 | 1 | 2 (none)]
// s0 : Player Index
// t0 : Character Index
// v0 : Player_Struct pointer
// v1 : Player Info Global Pointer (800A4D08 + i*0x74)
// Modified Registers
// at : comparison / (alt-char-state at end)
// t8 : alt-char-state array addr
scope restore_legal_char_CSS: {
  check_illegal_char:
  ori   at, r0, 0x02
  beq   at, a1, return       // If a1 = 2, no player
  ori   at, r0, 0x1C        // BD;
  beq   at, t0, return      // If t0 = 0x1C, no selected character
  sltiu at, t0, 0x0C        // BD;
  bnez  at, return          // if (char < 0x0C), legal, do not

  grab_alt_state_pointer:
  li    t8, alt_char_state  // BD;
  addu  t8, s0, t8          // offset alt-state pointer by player

  mm_check:
  ori   at, r0, 0x0D        // BD; Metal Mario
  beq   at, t0, mm_restore

  gdk_check:
  ori   at, r0, 0x1A        // BD; Giant Donkey Kong
  beq   at, t0, gdk_restore
  nop

  polygon_restore:
  subiu t0, t0, 0x000E
  ori   at, r0, AltState.POLYGON

  store_changes:
  sb    at, 0x0000(t8)      // store alt state
  sb    t0, 0x0023(v1)      // store changed character index

  return:
  j     CSS.hooks.restore_char_CSS + 8
  sw    r0, 0x001C(v0)      // original line of code

  mm_restore:
  ori   at, r0, AltState.MM
  b     store_changes
  or    t0, r0, r0          // t0 = mario

  gdk_restore:
  ori   at, r0, AltState.GDK
  b     store_changes
  ori   t0, r0, 0x02        // t0 = donkey kong
}
