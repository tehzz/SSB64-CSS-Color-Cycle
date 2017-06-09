//bass-n64
//=========================================================
//---Add "Winning Logos" for more than 12 Characters-------
//
// Replace the 12 member arrays with 27 (or any number)
// member arrays to have legal values for all on ROM
// characters. Also, this prevents 3 large arrays from
// being loaded on the stack by using references for the
// three new arrays
//=========================================================
//---Begin Hook------------------------
// All of this will be within the routine, so it's really one big hook..
//---Register Map------------
// t0 : winning character index (<< 2)
// t1 : array (logo, color, zoom) bases
//      array[winner.char * 4]
// t2 : 0x80000000 bitmask
// t3 : ram addr of resource-0035.bin
//---Stack Map---------------
// First Array  : 0x00A0 + sp
// Second Array : 0x0070 + sp
// Third Array  : 0x0040 + sp
//---------------------------
// Called from 0x80138DAC


pushvar pc
origin 0x151CC0
base 0x80132B20

scope char_logos_hooks {
  // this loads a "color" array for teams, and then gets the winning
  // character on the stack at 0xD0
  // End 80132C58
  constant put_winner_on_stack(0x80132BC8)
  constant end_put_winner(0x80132C58)
  constant ram_resource35(0x8013A058)
  // First, re-organize the beginning of the draw logo routine

prologue:
            subiu sp, sp, 0x00E0      // original stack space
            sw    ra, 0x0024(sp)      // original ra stack offset
            sw    s0, 0x0020(sp)      // original s0 stack offset
  // After this, the routine would load 3 arrays on the stack.
  // Instead, jump ahead to get the winning character index on the stack
grab_winning_char:
            b     put_winner_on_stack  // at 0xD4
            nop
load_array_values:
            lw    t0, 0x00D4(sp)      // grab winning character index
      lwAddr(t3, ram_resource35, 0)
            lui   t2, 0x8000          // load the mask for non-offset logo pointers
            sll   t0, t0, 0x2         // convert char index to word offset
      lwAddr(t1, data.char_logo_offsets, t0)
            and   at, t2, t1          // check if msb is set (aka it's a pointer to RAM)
            bnezl at, store_logo_offset
            sub   t1, t1, t3          // abuse likely branching to skip instruction if mask == 0
store_logo_offset:
            sw    t1, 0x00A0(sp)      // store logo DL offset at 0xA0(sp)

      lwAddr(t1, data.char_logo_color_offsets, t0)
            and   at, t2, t1
            bnezl at, store_logo_color_offset
            sub   t1, t1, t3
store_logo_color_offset:
            sw    t1, 0x00A4(sp)      // store logo color offset at 0xA4

            lwAddr(t1, data.char_logo_zoom_offsets, t0)
            and   at, t2, t1
            bnezl at, store_logo_zoom_offset
            sub   t1, t1, t3
store_logo_zoom_offset:
            sw    t1, 0x00AC(sp)      // store zoom offset at 0xAC

            or    a0, r0, r0          // replacement instruction from 80132C54
            or    a1, r0, r0          // replacement
            b     end_put_winner + 0x8
            addiu a2, r0, 0x0017      // replacement instruct

  nopUntilPC(put_winner_on_stack, "Character logo nop")
// End of mini-internal routine
origin 0x151DF8
base end_put_winner   //0x80132C58
            b     load_array_values
            nop

// First Array Load and Use
origin 0x151E1C
base 0x80132C7C
load_char_logo_dl:
            lw    t7, 0x00A0(sp)

//---Second Array Load and Use----
// 80132CBC lui   t2, 0x8014
//       C0 lw    t2, 0xA058(t2)
//       C4 addu  t5, sp, t8
//       C8 lw    t5, 0x0070(t5)
//       CC addu  t5, sp, t8
//       D0 jal   0x8000F8F4
//       D4 addu  a1, t5, t2    #file base + character offset
//--------------------------------
origin 0x151E68
base 0x80132CC8
load_color_dl:
            lw    t5, 0x00A4(sp)

// Third Array Load and Use
origin 0x151E8C
base 0x80132CEC
load_zoom_dl:
            lw    t3, 0x00AC(sp)
}

pullvar pc
// Verbose Print info [-d v on cli]
if {defined v} {
  print "Included more-char-logos.asm\n"
}
