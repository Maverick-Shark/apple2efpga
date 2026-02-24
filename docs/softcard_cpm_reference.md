# Softcard CP/M Reference

> Adapted/fixed from [Apple II Softcard CPM Reference (mirror)](http://mirrors.apple2.org.za/ftp.apple.asimov.net/documentation/os/cpm/Apple%20II%20Softcard%20CPM%20Reference.txt).
>
> Original author unknown. Errors/typos have been fixed, content expanded and formatted.

---

## Table of Contents

1. [Peripheral Card Standard Locations](#peripheral-card-standard-locations)
2. [Apple Disk Drives](#apple-disk-drives)
3. [Installing the Softcard](#installing-the-softcard)
   - [DIP Switches](#dip-switches)
4. [Apple Softcard CP/M Specific Programs](#apple-softcard-cpm-specific-programs)
   - [FORMAT](#format-drive)
   - [COPY](#copy-dest-drivesource-drives)
   - [CPM56](#cpm56-drive)
   - [CONFIGIO](#configio)
   - [APDOS](#apdos)
   - [DOWNLOAD](#download)
   - [RW13](#rw13)
   - [MBASIC/GBASIC](#mbasicgbasic)
5. [Typing at the Apple Softcard CP/M Keyboard](#typing-at-the-apple-softcard-cpm-keyboard)
   - [CP/M Warm Boot: Ctrl-C](#cpm-warm-boot-ctrl-c)
   - [Hitting the RESET Key](#hitting-the-reset-key)
6. [Changing CP/M Disks](#changing-cpm-disks)
7. [6502/Z-80 Address Translation](#6502z-80-address-translation)
8. [Apple II Softcard CP/M Memory Usage](#apple-ii-softcard-cpm-memory-usage)
   - [Apple II Softcard CP/M Memory Map](#apple-ii-softcard-cpm-memory-map)
9. [Interrupt Handling](#interrupt-handling)
10. [Console Cursor Addressing and Screen Control](#console-cursor-addressing-and-screen-control)
11. [Keyboard Redefinition](#keyboard-redefinition)
12. [Support of Non-Standard Peripherals and I/O Software](#support-of-non-standard-peripherals-and-io-software)
    - [Patching User Software Via the I/O Vector Table](#patching-user-software-via-the-io-vector-table)
13. [Calling of 6502 Subroutine](#calling-of-6502-subroutine)
14. [Presence and Location of Peripheral Cards](#presence-and-location-of-peripheral-cards)
15. [Microsoft SoftCard Version 2.20B BIOS](#microsoft-softcard-version-220b-bios)
16. [Microsoft SoftCard Version 2.23 BIOS](#microsoft-softcard-version-223-bios)
17. [CP/M Microsoft BIOS Patches](#cpm-microsoft-bios-patches)
18. [The CP/M RWTS](#the-cpm-rwts)
    - [The Apple CP/M Disk Parameter Tables](#the-apple-cpm-disk-parameter-tables)

---

## Peripheral Card Standard Locations

Apple peripheral cards — what goes where:

| Card Type | Card Name |
|-----------|-----------|
| 1 | Apple Disk II controller |
| 2* | Apple Communications Card / CCS 7710A Serial Interface |
| 3 | Apple Super Serial Card / Apple Silentype Printer / Videx Videoterm 24×80 / M&R Enterprises Sup-R-Term 24×80 |
| 4 | Apple Parallel Printer Card |

> \* The CCS 7710A card is preferred as it supports hardware handshaking and variable baud rates from 110 to 19200 baud. The Apple Communications Card requires hardware modification for baud rates other than 110 or 300 baud.

As a general rule, any card directly compatible with Apple Pascal without requiring software modifications will probably also be directly compatible with Apple CP/M. Other peripheral cards may be used if software supplied by the card manufacturer is bound to your Apple CP/M system using the `CONFIGIO` utility program.

| Slot | Valid Card | Purpose/Types |
|------|------------|---------------|
| 0 | Not used for I/O | Applesoft or Integer Basic ROM card / Language card (used by Apple CP/M) |
| 1 | 2, 3, 4 | Line printer interface (CP/M `LST:` device) |
| 2 | 2, 3, 4 | General purpose I/O (CP/M `PUN:` and `RDR:` devices) |
| 3 | 2, 3, 4 | Console output device (CP/M `CRT:` or `TTY:` device). Normal Apple 24×40 screen used if no card here. |
| 4 | 1 | Disk controller for drives E: and F: / Z80 Softcard may be installed here if no disk controller is present. |
| 5 | 1 | Disk controller for drives C: and D: |
| 6 | 1 | Disk controller for drives A: and B: (must be present) |
| 7 | Any type | No assigned purpose. The Z-80 SoftCard may be installed here.* |

> \* European Apple II's in PAL mode: only a PAL color card may be inserted in slot 7.

---

## Apple Disk Drives

|  | CP/M Name | Slot # | Drive # |
|--|-----------|--------|---------|
| 1st drive | A: | 6 | 1 |
| 2nd drive | B: | 6 | 2 |
| 3rd drive | C: | 5 | 1 |
| 4th drive | D: | 5 | 2 |
| 5th drive | E: | 4 | 1 |
| 6th drive | F: | 4 | 2 |

> **Note:** SoftCard CP/M up to 2.20B allows up to 6 drives, while versions 2.23, 2.25 and 2.26 allow only up to 4 drives. Generic CP/M allows up to 16 drives.

---

## Installing the Softcard

Make sure the four small DIP switches are all switched to the **OFF** position. This is the standard operating position for Apple CP/M.

Turn off your Apple II, insert the SoftCard into any unused slot except slot 0. The standard slot for the SoftCard is slot 4. If slot 4 is occupied by a disk controller card, choose another slot.

Insert the other peripheral cards according to the list above, then turn on your Apple II.

### DIP Switches

The four DIP switches are normally OFF for CP/M operation. Their functions when ON:

| Switch | Function when ON |
|--------|-----------------|
| 1-1 | Disable address translation |
| 1-2 | Higher priority DMA devices cause SoftCard to relinquish bus |
| 1-3 | Pass NMI line to Z80 |
| 1-4 | Pass IRQ line to Z80 |

---

## Apple Softcard CP/M Specific Programs

### FORMAT \<drive\>

```
FORMAT A:    ; Format disk in drive A:
```

The Apple CP/M disk formatter. *(Apple CP/M ver 2.23 and later has no FORMAT program — disk formatting is integrated into the COPY program.)*

---

### COPY \<dest drive\>=\<source drive\>[/S]

```
COPY B:=A:      ; Copy disk in A: to disk in B:
COPY A:=A:      ; Single-drive copy
COPY A:=A:/S    ; Copy only the CP/M system tracks
COPY            ; Prompts user for source and destination drives
```

The Apple CP/M disk copy program. Copies the entire disk, overwriting the whole destination. Can copy on a single drive (unlike `PIP`, which requires two drives).

---

### CPM56 \<drive\>

```
CPM56 A:
```

Updates the CP/M system from 44K CP/M to 56K CP/M. 56K CP/M requires a Language Card to work. CPM56 is preset only on the 16-sector Apple CP/M disk.

---

### CONFIGIO

An MBASIC program used to:
1. Redefine keyboard characters
2. Load User I/O Software
3. Configure Apple CP/M for use with an External Terminal

---

### APDOS

Transfers data (files) from Apple DOS disks to CP/M disks. May be used for text and binary files only. Does **not** transfer files from CP/M disks to Apple DOS disks — use the Apple DOS utility `CPMXFER` for that.

---

### DOWNLOAD

`DOWNLOAD` and `UPLOAD` enable the user to transfer CP/M files from another CP/M machine to the Apple by means of an RS-232 serial data link. `UPLOAD` is not included on the Apple CP/M disks but should be typed in and assembled on the other CP/M machine. Requires working knowledge of 8080 assembly language programming.

---

### RW13

Allows 16-sector Apple CP/M to access files on a 13-sector Apple CP/M disk. Requires at least two Disk II drives. RW13 is present only on the 16-sector Apple CP/M disk.

---

### MBASIC/GBASIC

```
MBASIC [/filename] [/F:<no_files>] [/M:<max_mem>] [/S:<max_recsize>]
```

| Option | Description |
|--------|-------------|
| `/filename` | Loads and executes a BASIC program file (`.BAS` default ext) |
| `/F:<no_files>` | Max number of concurrently open files (default=3). Each file requires 166+128 bytes extra. |
| `/M:<max_mem>` | Highest memory location used by MBASIC (default: all TPA) |
| `/S:<max_recsize>` | Max record size allowed by random files (default: 128) |

`<no_files>` and `<max_mem>` may be given as `<decimal>`, `&O<octal>` or `&H<hexadecimal>`.

These are Microsoft's MBASIC interpreter, adapted for Apple CP/M. **GBASIC** supports Apple hi-res graphics while **MBASIC** does not. Both support Apple lo-res graphics plus other Apple-specific things. GBASIC is present only on the 16-sector Apple CP/M disk.

---

## Typing at the Apple Softcard CP/M Keyboard

| Key | Action |
|-----|--------|
| `←` / `Ctrl`+`H` | Backspaces one character, deleting the char under the cursor |
| `Ctrl`+`X` | Backspaces to the beginning of the line, deleting the line |
| `Ctrl`+`R` | Retypes the current line |
| `Ctrl`+`J` | Terminates input — same as `RETURN` key |
| `Ctrl`+`E` | Physical end-of-line. Cursor moves to beginning of next line, but line is not terminated until `RETURN` is typed. |
| `RUBOUT` | Deletes and "echoes" (reprints) the last character typed. Also referred to as `DEL` or `DELETE` (ASCII 7Fh). Type `Ctrl`+`@` to get `RUBOUT` on the Apple ][/][+ keyboard. |

A few characters normally unavailable on the Apple ][/][+ keyboard have been assigned to certain control characters:

| Type | To Get |
|------|--------|
| `Ctrl`+`K` | `[` |
| `Ctrl`+`@` | `RUBOUT` |
| `Ctrl`+`B` | `\` |
| `Ctrl`+`U` | `TAB` (`Ctrl`+`I`) |

These control characters can be redefined with the `CONFIGIO` program.

### Output Control

| Key | Action |
|-----|--------|
| `Ctrl`+`S` | Temporarily stops character output to `TTY:`. Output resumes when any character is typed. |
| `Ctrl`+`P` | Sends all character output to `LPT:` as well as to `TTY:`. This "printer echo" mode remains in effect until another `Ctrl`+`P` is typed. |

### CP/M Warm Boot: Ctrl-C

When `Ctrl`+`C` is typed as the first character on a line, CP/M performs a "warm boot", causing CP/M to be reloaded from disk to ensure it is in working order. You should **ALWAYS** type `Ctrl`+`C` whenever you change disks.

### Hitting the RESET Key

**Autostart ROM:** Hitting `RESET` while in CP/M will cause CP/M to warm boot. Hitting `RESET` while in MBASIC/GBASIC will result in a "Reset error", which can be trapped using `ON ERROR GOTO`.

**Older Monitor ROM:** Hitting `RESET` lands you in the Apple Monitor. You can recover by typing `Ctrl`+`Y` RETURN, after which the behavior will be the same as for the Autostart ROM.

---

## Changing CP/M Disks

Unlike Apple DOS, you cannot indiscriminately change disks with CP/M. Certain disk directory information is stored in memory at all times. When you change disks, type `Ctrl`+`C` to execute a CP/M "warm boot" **after** you have changed the disks.

If you don't type `Ctrl`+`C` after changing disks and a **WRITE** is attempted to the changed disk, CP/M will display:

```
  BDOS ERR ON x:Disk R/O
```

(where `x:` is a disk drive A:–F:). When you receive this message, hit RETURN to perform a CP/M warm boot, terminating any running application.

> **Note:** No error will result if you attempt to READ from the changed disk without having typed `Ctrl`+`C` first.

---

## 6502/Z-80 Address Translation

The SoftCard performs address translation from the Z-80 to the Apple II address bus. Z-80 addresses are written with a trailing `H`; 6502 addresses are written with a leading `$`.

| Z-80 Addr | 6502 Addr | Notes |
|-----------|-----------|-------|
| 0000H–00FFH | $1000–$1FFF | Z-80 address zero |
| 1000H–10FFH | $2000–$2FFF | |
| 2000H–20FFH | $3000–$3FFF | |
| 3000H–30FFH | $4000–$4FFF | |
| 4000H–40FFH | $5000–$5FFF | |
| 5000H–50FFH | $6000–$6FFF | |
| 6000H–60FFH | $7000–$7FFF | |
| 7000H–70FFH | $8000–$8FFF | |
| 8000H–80FFH | $9000–$9FFF | |
| 9000H–90FFH | $A000–$AFFF | |
| 0A000H–0AFFFH | $B000–$BFFF | |
| 0B000H–0BFFFH | $D000–$DFFF | |
| 0C000H–0CFFFH | $E000–$EFFF | |
| 0D000H–0DFFFH | $F000–$FFFF | 6502 RESET, NMI, BREAK vectors |
| 0E000H–0EFFFH | $C000–$CFFF | 6502 memory mapped I/O |
| 0F000H–0FFFFH | $0000–$0FFF | 6502 zero page, stack, Apple screen, CP/M RWTS |

> Translation may be turned off by setting DIP switch S1-1 to ON.

---

## Apple II Softcard CP/M Memory Usage

| 6502 Address | Z-80 Address | Use |
|-------------|-------------|-----|
| $0800–$0FFF | 0F800H–0FFFFH | Apple CP/M disk drivers and buffers ("RWTS") |
| $0400–$07FF | 0F400H–0F7FFH | Apple screen memory |
| $0200–$03FF | 0F200H–0F3FFH | I/O config block, device drivers |
| $0000–$01FF | 0F000H–0F1FFH | Reserved: 6502 page zero and 6502 stack |
| $C000–$CFFF | 0E000H–0EFFFH | Apple memory mapped I/O |
| $FFFA–$FFFF | 0DFFAH–0DFFFH | 6502 RESET, NMI and BREAK vectors |
| $D400–$FFF9 | 0C400H–0DFF9H | 56K Language Card CP/M (if Lang. Card installed) |
| $D000–$D3FF | 0C000H–0C3FFH | Top 1K of free RAM with 56K CP/M |
| $A400–$BFFF | 9400H–0AFFFH | 44K CP/M (free memory with 56K CP/M) |
| $1100–$A3FF | 0100H–93FFH | Free RAM |
| $1000–$10FF | 0000H–00FFH | CP/M page zero |

| CP/M Size | Language Card Usage |
|-----------|-------------------|
| 44K CP/M | Does not use Language Card |
| 56K CP/M | Uses Language Card, bank 2 only (TPA) |
| 60K CP/M | Uses Language Card: bank 2 for TPA, bank 1 for parts of BDOS+BIOS |

> **Note:** The Apple II hi-res graphics screens are situated right in the middle of the Softcard CP/M TPA. Hi-res graphics programming on SoftCard CP/M therefore requires special precautions. Microsoft GBASIC solves this by reserving an 8K memory area in the middle of the Basic interpreter for hi-res graphics.

### Apple II Softcard CP/M Memory Map

```
         Z80 addr               6502 addr

       ______________         ______________
0000H |CP/M zero page| $1000 |              |
      |______________|       |              |
0100H |CP/M TPA start|       |              |
      |              |       |              |
      |              |       |              |
      |______________|       |______________|
1000H |              | $2000 |              |
      |              |       |  Aux Hi-res  |
      |   CP/M TPA   |       |   page 1X    |
      |______________|       |______________|
3000H |              | $4000 |              |
      |              |       |  Aux Hi-res  |
      |   CP/M TPA   |       |   page 2X    |
      |______________|       |______________|
5000H |              | $6000 |              |
      |   CP/M TPA   |       |              |
            ...                    ...
      |______________|       |              |
9400H |   44K BDOS   | $A400 |              |
      |  starts here |       |              |
      | CP/M 56/60K  |       |              |
      |     TPA      |       |              |
      | 44K BIOS end |       |              |
AFFFH |______________| $BFFF |______________|
B000H |              | $D000 |  LC bank 1   |  LC bank 2  |
      | CP/M 56/60K  |       |  60K BDOS+   |  Used by    |
      |     TPA      |       |  BIOS        |  CP/M       |
C000H |              | $E000 |   Language Card            |
C400H |   56K BDOS   | $E400 |              |
      |  starts here |       |              |
D400H |   60K BDOS   | $F400 |              |
D800H |   56K BIOS   | $F800 |              |
DFFFH |______________| $FFFF |______________|
E000H        $C000 |   Motherboard I/O      |
E090H        $C090 |   Slot I/O (DEVSEL)    |
E100H        $C100 |   Slot CX ROM (IOSEL)  |
EFFFH        $CFFF |________________________|

       ______________         ______________
F000H | Unused by Z80| $0000 |6502 zero page|
F100H | Unused by Z80| $0100 |  6502 stack  |
F200H | I/O cfg blk  | $0200 |  Keybd buff  |
F300H | Patch area   | $0300 |  Page 3      |
F400H | Text/lores GR| $0400 | Text/lores GR|
      |              |       |   page 1     |
F800H |   CP/M RWTS  | $0800 | Text/lores GR|
      |              |       |   page 2     |
FFFFH |______________| $0FFF |______________|
```

---

## Interrupt Handling

Interrupts on the Z80 side are normally disabled. Setting DIP switches 1-3 and 1-4 to ON passes the NMI and IRQ lines, respectively, to the Z-80.

Because of the way the 6502 is "put to sleep" by the Z-80 SoftCard using the DMA line on the Apple bus, **ALL interrupt processing must be handled by the 6502**. An interrupt can occur at two times:

**In 6502 mode:** Handle the interrupt in the usual way; simply end the interrupt processing routine with an `RTI` instruction.

**In Z-80 mode:** Both processors are interrupted. Step-by-step process:

1. Save any registers that are destroyed on the stack.
2. Save the contents of the 6502 subroutine call address in case an interrupt occurred during a 6502 subroutine call.
3. Set up the 6502 subroutine call address to `FF58` (address of a 6502 `RTS` instruction in the Apple Monitor ROM).
4. Return control to the 6502 by performing a write to the address of the Z-80 card.
5. When control is returned to the Z-80, restore the previous 6502 subroutine call address.
6. Restore all used Z-80 registers from the stack.
7. Enable interrupts with an `EI` instruction.
8. Return with a `RET` instruction.

---

## Console Cursor Addressing and Screen Control

There are nine screen functions supported by Apple CP/M:

1. Clear Screen
2. Clear to End of Page
3. Clear to End of Line
4. Set Normal (lolite) Text Mode
5. Set Inverse (hilite) Text Mode
6. Home Cursor
7. Address Cursor
8. Move Cursor Up
9. Non-destructively Move Cursor Forward

The Backspace character (`Ctrl-H`, ASCII 8) moves the cursor backwards, and the Line Feed character (`Ctrl-J`, ASCII 10) moves the cursor down one line.

Screen function character sequences may be:
1. A single control character, or
2. Any ASCII characters preceded by a single character lead-in

> Screen function sequences longer than two characters are not supported.

| Funct # | Software Addr | Hardware Addr | Description |
|---------|--------------|---------------|-------------|
| — | 0F396H | 0F3A1H | Cursor addr coordinate offset (Range 0–127). Hi bit=0: Y first, X last. Hi bit=1: X first, Y last. |
| — | 0F397H | 0F3A2H | Lead-in character; zero if no lead-in |
| 1 | 0F398H | 0F3A3H | Clear Screen |
| 2 | 0F399H | 0F3A4H | Clear to End of Page |
| 3 | 0F39AH | 0F3A5H | Clear to End of Line |
| 4 | 0F39BH | 0F3A6H | Set Normal (lo-lite) Text Mode |
| 5 | 0F39CH | 0F3A7H | Set Inverse (hi-lite) Text Mode |
| 6 | 0F39DH | 0F3A8H | Home Cursor |
| 7 | 0F39EH | 0F3A9H | Address Cursor |
| 8 | 0F39FH | 0F3AAH | Move Cursor Up One Line |
| 9 | 0F3A0H | 0F3ABH | Non-destructively Move Cursor Forward |

The Hardware and Software Screen Function Tables can be examined and modified with the `CONFIGIO` program.

---

## Keyboard Redefinition

Keyboard redefinition takes place only during input from the `TTY:` and `CRT:` devices. The Keyboard Character Redefinition Table supports up to **six** character redefinitions. Located at `0F3ACH` from the Z-80.

Entries are two bytes: the first is the ASCII value of the character to be redefined, the second is the redefined ASCII character. Both bytes must have their high bits cleared. If there are fewer than six entries, the end of the table is denoted by a byte with the high order bit set.

Modifications can be made using the `CONFIGIO` program.

---

## Support of Non-Standard Peripherals and I/O Software

All primitive character I/O functions are vectored through the I/O Vector Table within the I/O Config Block. Three blocks of 128 bytes each are provided for user I/O driver software:

| Address | Assigned Slot | Assigned Logical Device |
|---------|--------------|------------------------|
| 0F200H–0F27FH | 1 | `LST:` — line printer device |
| 0F280H–0F2FFH | 2 | `PUN:` and `RDR:` — general purpose I/O |
| 0F300H–0F37FH | 3 | `TTY:` — the console device |

I/O driver subroutines are patched to Apple CP/M by patching the appropriate I/O vector:

| Vec # | Addr | Vector Name | Description |
|-------|------|------------|-------------|
| 1 | 0F380H | Console Status | Return `0FFH` in A if char ready, `00H` if not |
| 2 | 0F382H | Console Input #1 | Return char from console into A with |
| 3 | 0F384H | Console Input #2 | hi bit clear |
| 4 | 0F386H | Console Output #1 | Send ASCII char in C to |
| 5 | 0F388H | Console Output #2 | console device |
| 6 | 0F38AH | Reader Input #1 | Read char from "Paper Tape Reader" |
| 7 | 0F38CH | Reader Input #2 | device into A |
| 8 | 0F38EH | Punch Output #1 | Send char in C to "Paper Tape Punch" |
| 9 | 0F390H | Punch Output #2 | device |
| 10 | 0F392H | List Output #1 | Send char in C to |
| 11 | 0F394H | List Output #2 | "Line Printer" device |

| Vec # | Addr SS BIOS | Addr PS IIe BIOS | Device |
|-------|-------------|-----------------|--------|
| 1 | 0F380H | 0F3C0H | Console status |
| 2 | 0F382H | 0F3C2H | Input `TTY:` = `CRT:` |
| 3 | 0F384H | 0F3C4H | Input `UC1:` |
| 4 | 0F386H | 0F3C6H | Output `TTY:` = `CRT:` |
| 5 | 0F388H | 0F3C8H | Output `UC1:` |
| 6 | 0F38AH | 0F3CAH | Input `PTR:` |
| 7 | 0F38CH | 0F3CCH | Input `UR1:` = `UR2:` |
| 8 | 0F38EH | 0F3CEH | Output `PTP:` |
| 9 | 0F390H | 0F3D0H | Output `UP1:` = `UP2:` |
| 10 | 0F392H | 0F3D2H | Output `LPT:` |
| 11 | 0F394H | 0F3D4H | Output `UL1:` |

### IOBYTE Device Assignment

The `IOBYTE` at address `0003H` controls logical-to-physical device assignment:

| `IOBYTE` bits | 7–6 | 5–4 | 3–2 | 1–0 |
|---------------|-----|-----|-----|-----|
| Field | LIST | PUNCH | READER | CONSOLE |

**CONSOLE field (bits 0,1):**
- `0` → `TTY:` device
- `1` → `CRT:` device
- `2` → `BAT:` — batch mode (uses `RDR:` for input and `LST:` for output)
- `3` → `UC1:` — user defined CONSOLE device

**READER field (bits 2,3):**
- `0` → `TTY:` device
- `1` → `PTR:` device ("paper tape reader")
- `2` → `UR1:` — user defined READER device #1
- `3` → `UR2:` — user defined READER device #2

**PUNCH field (bits 4,5):**
- `0` → `TTY:` device
- `1` → `PTP:` device ("paper tape punch")
- `2` → `UP1:` — user defined PUNCH #1
- `3` → `UP2:` — user defined PUNCH #2

**LIST field (bits 6,7):**
- `0` → `TTY:` device
- `1` → `CRT:` device
- `2` → `LPT:` device ("line printer")
- `3` → `UL1:` — user defined LIST device

**Default device assignments:**
- `CON:` = `CRT:`
- `RDR:` = `PTR:`
- `PUN:` = `PTP:`
- `LST:` = `LPT:`

The `IOBYTE` can be changed with the `STAT` program, or from assembly language using CP/M functions #7 (Get IOBYTE) and #8 (Set IOBYTE).

### Patching User Software Via the I/O Vector Table

User subroutines can be patched into the I/O Configuration Block with the `CONFIGIO` program. Format of a disk code file to be loaded with `CONFIGIO`:

| Bytes | Content |
|-------|---------|
| 1st byte | Number of patches to I/O Vector Table |
| Next 2 bytes | Destination address of program code |
| Next 2 bytes | Length of program code |
| *For each vector patch:* | |
| 1 byte | Vector Patch type: 1 or 2 |
| *If type = 1:* | |
| 1 byte | Vector number to be patched (1–11) |
| 2 bytes | Address to be patched into the vector |
| *If type = 2:* | |
| 1 byte | Vector number to be patched (1–11) |
| 2 bytes | Address in which to place current contents of the vector |
| 2 bytes | New address to be placed in the specified vector |
| After: | Actual program code (max 128 bytes per slot-dependent block) |

---

## Calling of 6502 Subroutine

The 6502 is enabled from the Z-80 by a WRITE to the slot-dependent location `0EN00H`, where N is the slot location of the Z-80 card. When the system is booted, the location of the SoftCard is determined and its address is stored in the I/O Configuration Block.

| Z-80 Addr | 6502 Addr | Purpose |
|-----------|-----------|---------|
| 0F045H | $45 | 6502 A register pass area |
| 0F046H | $46 | 6502 X register pass area |
| 0F047H | $47 | 6502 Y register pass area |
| 0F048H | $48 | 6502 P register pass area |
| 0F049H | $49 | Contains 6502 stack pointer on exit |
| 0F3DEH | — | Address of Z-80 Softcard stored here as `0EN00H` |
| 0F3D0H | — | Address of 6502 subroutine to be called stored here |
| — | $3C0 | Start address of 6502-to-Z80 mode switching routine |

**$3C0 routine:**

```asm
03C0:   LDA $C083       ; Put Apple Language Card into read/write mode
        LDA $C083
        STA SOFTCARD    ; Enable SoftCard, disable 6502
START:  LDA $C081       ; Enable Apple Monitor ROM
        JSR SET6502     ; Load the 6502 registers from $45 to $48
        JSR ROUTINE     ; Run the 6502 subroutine
        STA $C081       ; Make sure ROM is enabled
        SEI             ; Disable 6502 interrupts
        JSR SAVE        ; Store 6502 registers into $45 to $49
        JMP $3C0        ; Loop back to beginning
```

> **Note:** Locations `$800`–`$FFF` are used by the Apple CP/M disk drivers and buffers ("RWTS") and are **NOT** available for use by a 6502 subroutine.

**Language Card Users:** When in Z-80 mode, the Language Card RAM is both read- and write-enabled. When a 6502 subroutine is called, the Apple on-board ROM is automatically enabled. However, the Language Card RAM is write-enabled during a 6502 call — a write to any location above `$D000` will write to the Language Card RAM.

---

## Presence and Location of Peripheral Cards

The Card Type Table is located at `0F3B9H`. The entry for a given slot is at `0F3B8H + S`, where S is 1–7.

| Value | Type |
|-------|------|
| 0 | No peripheral card ROM detected |
| 1 | A peripheral card ROM of unknown type was detected |
| 2 | Apple Disk II Controller card |
| 3 | Apple Communications Card or CCS 7710A Serial Interface |
| 4 | Super Serial Card, Videx Videoterm, M&R Sup-R-Term, or Apple Silentype |
| 5 | Apple Parallel Printer Card |
| 6 | Firmware Card (SoftCard CP/M ver 2.23 and higher) |

The Disk Count Byte at `0F3B8H` equals the number of disk controller cards × 2.

Each peripheral card has signature bytes at `$Cn05`, `$Cn07`, `$Cn0B`, `$Cn0C` (where `n` is the slot number):

| Card Type | $Cn05 | $Cn07 | $Cn0B |
|-----------|-------|-------|-------|
| Parallel Card | $48 | $48 | |
| Communications Card | $18 | $38 | |
| Super Serial Card | $38 | $18 | |
| Disk Controller Card | $03 | $3C | |
| Firmware Card | | | $01 |

---

## Microsoft SoftCard Version 2.20B BIOS

The BIOS for the Microsoft Softcard 56K CP/M version 2.20B extends into the Apple Language Card area but uses only bank 2 of the Language Card. All logical device routines use the IOCB. The IOBYTE is used to determine which physical device is to be used.

| Start | End | Use |
|-------|-----|-----|
| DA00H | DA32H | BIOS vector jump tables |
| DA33H | DA92H | Disk Parameter Headers for six drives |
| DA93H | DAA1H | Disk Parameter Block |
| DAA2H | DAC4H | Slot init routine (ACIA set to 7 data bits, even parity, 2 stop bits, xmit interrupts enabled) |
| DAC5H | DACBH | Routine to place `En00H` in HL where n = slot # passed in E |
| DACCH | DB07H | WBOOT routine |
| DB08H | DB0BH | CONST — Console Status from IOCB at F380H |
| DB0CH | DB11H | CONST routine for Apple keyboard |
| DB12H | DB28H | CONIN — Console Input routine |
| DB29H | DB3AH | Default address in IOCB for console input |
| DB3BH | DB41H | Routine to set up and make call to the 6502 |
| DB43H | DB4FH | CONOUT — checks IOBYTE for the output device |
| DB50H | DB61H | Character input routine |
| DB62H | DB65H | Jump to the physical PTR: device |
| DB66H | DB74H | LIST — logical LST: device routine |
| DB75H | DB86H | PUNCH — logical PUN: device |
| DB87H | DB95H | READER — logical RDR: device |
| DB96H | DBB7H | Routine for 80-column cards |
| DBB8H | DBDFH | Routine to position cursor in GOTOXY sequence |
| DBE0H | DBF4H | Check for terminal lead-in character and call routines as required |
| DBF5H | DC3DH | Final character printing to console via TTY: or UC1: |
| DC3EH | DC43H | Physical TTY: device (general console output, slot 3) |
| DC44H | DCDEH | Screen output routine for standard 40-column Apple screen |
| DCDFH | DCE9H | Comm card output routine |
| DCEEH | DD03H | Preparatory routine for setting up a serial card |
| DD04H | DD11H | Serial card output routine (calls 6502) |
| DD12H | DD1BH | Comm card input routine |
| DD1CH | DD2AH | Serial card input routine |
| DD2BH | DD30H | Physical LPT: device output function (slot 1) |
| DD31H | DD3EH | Parallel card output routine |
| DD3FH | DD44H | Physical PTP: device output function (slot 2) |
| DD45H | DD4CH | Physical PTR: device input function (slot 2) |
| DD4BH | DD55H | HOME — select track 0 |
| DD56H | DD5AH | SETTRK — select the track in register C |
| DD5BH | DD6CH | Computational routine for peripheral card drivers and disk I/O |
| DD6DH | DD88H | SELDSK — select disk drive |
| DD89H | DD8DH | SETSEC — select the 128-byte CP/M sector |
| DD8EH | DD92H | SETDMA — select the disk I/O buffer address |
| DD93H | DDA2H | READ — set up disk read operation |
| DDA3H | DDF1H | WRITE — perform disk write operation |
| DDF2H | DE72H | Used by both READ and WRITE for CP/M protocols |
| DE73H | DE91H | Do actual read or write by calling the 6502 CP/M RWTS |
| DE92H | DEA1H | CP/M logical sector skew table |
| F200H | F37FH | I/O Patch area |
| F380H | F395H | IOCB with vectors to CP/M physical devices |
| F396H | F3AAH | Console function table (adapts to various terminals) |
| F3C0H | F3FFH | Space used by Apple Monitor ROM to vector interrupts and resets |
| F800H | F900H | Data buffer used by CP/M RWTS |
| FA00H | FFFCH | CP/M RWTS routines (written in 6502 assembly) |

### The CPM56.COM Map

`CPM56.COM` contains the entire 56K CP/M system image. Modify the BIOS by patching a copy of CPM56.COM, then run it to store the patched system on system tracks.

| Start | End | Use |
|-------|-----|-----|
| 100H | 2FFH | Command portion of CPM56.COM |
| 300H | 3FFH | Boot 1: loads RWTS into $A000–$FFFF, boot 2 into $1000–$13FF |
| 400H | 9FFH | CP/M RWTS |
| A00H | BFFH | Boot 2 |
| C00H | D7FH | I/O Patch area → moved to F200H–F37FH |
| D80H | | IOCB console status vector |
| D82H | | IOCB console input vector 1 (TTY:) |
| D84H | | IOCB console input vector 2 (UC1:) |
| D86H | | IOCB console output vector 1 (TTY:) |
| D88H | | IOCB console output vector 2 (UC1:) |
| D8AH | | IOCB reader vector 1 (PTR:) |
| D8CH | | IOCB reader vector 2 (UR1:) |
| D8EH | | IOCB punch vector 1 (PTP:) |
| D90H | | IOCB punch vector 2 (UP1:) |
| D92H | | IOCB list vector 1 (LST:) |
| D94H | | IOCB list vector 2 (UL1:) |
| D96H | DFFH | Console hardware/software definition tables → moved to F380H–F3FFH |
| E00H | 15FFH | CCP |
| 1600H | 23FFH | BDOS |
| 2400H | 29A7H | BIOS |
| 29A8H | 29E7H | Cold boot routine |
| 29E8H | 29FFH | Patches for 2.20B turnkey and disk read/write fix |

### The CPM56 Diskette Map

| Trk Start | Sec Start | Trk End | Sec End | Use |
|-----------|----------|---------|---------|-----|
| 00H | 00H | | | Boot 1 sector |
| 00H | 01H | 00H | 06H | CP/M RWTS |
| 00H | 07H | 00H | 08H | Boot 2 routine |
| 00H | 09H | 00H | 0AH | I/O Patch Area, page F300H routines+tables |
| 00H | 0BH | 01H | 02H | CCP |
| 01H | 03H | 02H | 00H | BDOS |
| 02H | 01H | 02H | 06H | BIOS |

### CPM56 Card Driver Entry Points

| Addr | Entry Point |
|------|------------|
| DCDFH | Communications Card output routine |
| DD04H | Serial Card output routine |
| DD12H | Communications Card input routine |
| DD1CH | Serial Card input routine |
| DD31H | Parallel Card output routine |

> All entry points require DE to contain the card slot number. The A and C registers are used as required by CP/M protocols.

---

## Microsoft SoftCard Version 2.23 BIOS

Version 2.23 corrects most problems in 2.20B hardware interfacing. Key improvements:

- **Firmware Card support:** Version 2.23 uses Apple Computer's protocols for Firmware Cards. Version 2.20B could not identify Firmware Cards.
- **ACIA fix:** The BIOS Comm Card driver now uses the 6502 instead of the Z-80 to access the ACIA. The Z-80 memory refresh caused the data port to be pre-read, clearing ACIA status flags and potentially losing data.
- **Bigger TPA:** The 60K 2.23 BIOS uses both 4K banked memories in the Language Card — bank 1 for BIOS disk-handling routines, bank 2 available for program memory.

| Start | End | Use |
|-------|-----|-----|
| F200H | F37FH | I/O Patch area |
| F380H | F395H | IOCB with vectors to CP/M physical devices |
| F396H | F3AAH | Console function table |
| $3C0 | $3DA | Routine which calls the 6502 microprocessor |
| $3F0 | $3FF | Apple Monitor ROM interrupt/reset vectors |
| $800 | $900 | Default I/O buffer area used by CP/M RWTS |
| $900 | $9FF | Nibble buffer used by CP/M RWTS |
| FA00H | FA32H | BIOS vector jump tables |
| FA33H | FA92H | Disk Parameter Headers for six drives |
| FA93H | FAA1H | Disk Parameter Block |
| FAB8H | FB0FH | WBOOT routine |
| FB10H | FB13H | CONST — Console Status |
| FB1AH | FB32H | CONIN — Console Input routine |
| FB4DH | FB59H | CONOUT |
| FBA0H | FBCAH | Routine for 80-column cards |
| $C00 | $C55 | One of the CP/M RWTS nibble buffers |
| FC6BH | FCB4H | Final character printing to console |
| FD0EH | FD27H | Comm card output routine (using 6502 code) |
| FD71H | FD82H | Serial card output routine |
| FD99H | FDA8H | Firmware Card console status routine |
| FDA9H | FDB6H | Firmware Card output routine |
| FDB7H | FDC0H | Firmware Card input routine |
| FDC1H | FDCFH | Serial card input routine |
| $DD0 | $DE0 | Firmware Card initialization routine |
| $E00 | $E02 | CP/M entry to warm loader routine |
| $E0F | $E1C | Firmware Card input routine |
| FE75H | FE7FH | HOME — select track 0 |
| FE80H | FE84H | SETTRK — select track in register C |
| FE97H | FEC5H | SELDSK — select disk drive |

**Language Card bank 1:**

| Start | End | Use |
|-------|-----|-----|
| $D000 | $D246 | First segment of CP/M RWTS |
| B247H | B256H | Disk read operation |
| B257H | B270H | Disk write operation |
| B271H | B333H | Used by both READ and WRITE |
| B334H | B358H | Actual read or write (calls 6502 CP/M RWTS) |
| B359H | B368H | CP/M logical sector skew table |
| $D369 | $D5BC | Second segment of CP/M RWTS |
| B5C0H | BFFFH | Second BDOS segment |

### The CPM60.COM Map

| Start | End | Use |
|-------|-----|-----|
| 100H | 3FFH | Command portion of CPM60.COM |
| 400H | 4FFH | Boot 1 |
| 500H | 746H | First segment of CP/M RWTS |
| 747H | 858H | BIOS read/write disk handling routines |
| 859H | AFFH | Second segment of CP/M RWTS |
| B00H | CFFH | Boot 2 |
| D00H | E7FH | I/O Patch area → moved to F200H–F37FH |
| F00H | 17FFH | CCP |
| 1800H | 1BFFH | Non-Language Card BDOS segment + prenibblizing RWTS routines |
| 1C00H | 26FFH | Language Card segment of BDOS |
| 2700H | 2BE9H | BIOS |
| 2BEAH | 2BFFH | Cold boot routine |

### The CPM60 Diskette Map

| Trk Start | Sec Start | Trk End | Sec End | Use |
|-----------|----------|---------|---------|-----|
| 00H | 00H | | | Boot 1 sector |
| 00H | 01H | 00H | 06H | CP/M RWTS and Z-80 BIOS disk routines |
| 00H | 07H | 00H | 08H | Boot 2 routine |
| 00H | 09H | 00H | 0AH | I/O Patch Area, page F300H routines+tables |
| 00H | 0BH | 01H | 03H | CCP |
| 01H | 04H | 01H | 07H | First segment of BDOS |
| 01H | 08H | 02H | 02H | Second segment of BDOS |
| 02H | 03H | 02H | 03H | BIOS |

### CPM60 Card Driver Entry Points

| Addr | Entry Point |
|------|------------|
| FD0EH | Communications Card output routine |
| FD71H | Serial Card output routine |
| FDA9H | Firmware Card output routine |
| FDB7H | Firmware Card input routine |
| FDC1H | Serial Card input routine |
| FE4BH | Communications Card input routine |
| FE5BH | Parallel Card output routine |

---

## CP/M Microsoft BIOS Patches

### Squashing ver 2.20B Bugs

**Bug 1:** Exchanges the `PTP:` and `UP1:` devices (usually unnoticed because they point to the same device by default):

```
DDT CPM56.COM
#S2581
2581 20   (type 28)
.
#<Ctrl-C>
SAVE 42 CPM56.COM
CPM56 A:
```

**Bug 2:** Apple IIe 80-column card warm boot clears screen — remove call to initialization routine in warm boot:

```
Addr   Old   New
24D8    CD    00
24D9    A2    00
24DA    DA    00
```

### Squashing ver 2.23 Bugs

An error in `RDR:` vectoring and the Apple IIe warm boot problem are present. Change the following locations in CPM60.COM:

```
Addr   Old   New

0EF4    A6    00    (corrects the IIe warm boot problem)
27C4    CD    00
27C5    82    00
27C6    DA    00

2897    08    04    (corrects the RDR: vector problem)

SAVE 44 CPM60.COM
CPM60 A:
```

---

## The CP/M RWTS

Written in 6502 code, resides at `$800`–`$FFF` including buffers. Entry point at `$E03` (for BIOS ver 2.20B and 2.23). Before calling, the following memory areas must be filled:

| Address | Content |
|---------|---------|
| $3E0 | Track to be accessed |
| $3E1 | CP/M physical sector (Apple sectors: $0–$F with skew) |
| $3E1–$3E3 | Volume number holdovers from DOS 3.3 — put $00 here |
| $3E4 | Drive number (DOS 3.3 style: 1 or 2) |
| $3E5 | Last drive used (DOS 3.3 holdover) |
| $3E6 | Slot number × 16 (Slot 6 → put $60) |
| $3E7 | Last slot (× 16) accessed |
| $3E8–$3E9 | I/O buffer address (256 bytes). Buffer at $800 → $3E8=$00, $3E9=$08 |
| $3EA | Error code: $00=none, $10=write protected, $40=drive error |
| $3EB | Command: $01=read sector, $02=write sector |
| $800–$900 | Default I/O buffer area |
| $900–$9FF | Nibble buffer |

**CP/M warm loader** is located at `$E00` for ver 2.20B and 2.23.

The first 3 tracks ($00–$02) are reserved for the boot routine, the CCP, BDOS and BIOS. Track $03 contains the CP/M directory (only 6 physical sectors = CP/M logical sectors 00H–0BH).

SoftCard CP/M ver 2.23 and higher creates a dummy file `cp/m.sys` in user area 31 allocated to the system tracks, making them accessible for data storage while remaining invisible to the user. `COPY.COM` has an option to create a "data diskette" (without `cp/m.sys`), gaining 3 more tracks for data — such a diskette cannot be warm booted.

### Sector Interleave Table

| CP/M Logical | CP/M Physical | DOS 3.3 | Apple Physical |
|-------------|--------------|---------|---------------|
| 00, 01 | 0 | 0 | 0 |
| 02, 03 | 9 | 6 | 3 |
| 04, 05 | 3 | C | 6 |
| 06, 07 | C | 3 | 9 |
| 08, 09 | 6 | 9 | C |
| 0A, 0B | F | F | F |
| 0C, 0D | 1 | E | 2 |
| 0E, 0F | A | 5 | 5 |
| 10, 11 | 4 | B | 8 |
| 12, 13 | D | 2 | B |
| 14, 15 | 7 | 8 | E |
| 16, 17 | 8 | 7 | 1 |
| 18, 19 | 2 | D | 4 |
| 1A, 1B | B | 4 | 7 |
| 1C, 1D | 5 | A | A |
| 1E, 1F | E | 1 | D |

> **Apple CP/M has double sector skewing:** system tracks use CP/M physical sector skew, while data tracks use logical sector skew.

---

## The Apple CP/M Disk Parameter Tables

### DPH — Disk Parameter Header

Obtain a pointer to the DPH by loading C with the disk drive number (0=A:, 1=B:, etc.) and calling BIOS function `SELDSK` (entry at `xx1BH`). On return, HL points to the DPH:

| Offset | Contents | Use |
|--------|---------|-----|
| 00H | XLT | Addr of logical-to-physical sector translation vector. On Apple CP/M, XLT=0000H (sector skewing is done in 6502 RWTS). |
| 02H | 0000H | Scratchpad for BDOS |
| 04H | 0000H | Scratchpad for BDOS |
| 06H | 0000H | Scratchpad for BDOS |
| 08H | DIRBUF | Addr of 128-byte directory buffer |
| 0AH | DPB | Addr of Disk Parameter Block for this drive |
| 0CH | CSV | Addr of scratchpad area to check for changed disks |
| 0EH | ALV | Addr of scratchpad area for disk allocation info |

### DPB — Disk Parameter Block

| Offset | Field | Use |
|--------|-------|-----|
| 00H | SPT 16b | Total 128-byte sectors per track |
| 02H | BSH 8b | Data allocation block shift factor (3→1K, 4→2K, 5→4K, …) |
| 03H | BLM 8b | Data allocation block mask (7→1K, 0FH→2K, 1FH→4K, …) |
| 04H | EXM 8b | Extent mask |
| 05H | DSM 16b | Total storage capacity in blocks minus one |
| 07H | DRM 16b | Total directory entries minus one |
| 09H | AL0 8b | Directory allocation bitmap, byte 0 |
| 0AH | AL1 8b | Directory allocation bitmap, byte 1 |
| 0BH | CKS 16b | Size of directory check vector |
| 0DH | OFF 16b | Number of reserved tracks at beginning of logical disk |

**BSH/BLM/EXM by block size (BLS):**

| BLS | BSH | BLM | EXM (DSM<256) | EXM (DSM≥256) |
|-----|-----|-----|---------------|---------------|
| 1024 | 3 | 7 | 0 | n/a |
| 2048 | 4 | 15 | 1 | 0 |
| 4096 | 5 | 31 | 3 | 1 |
| 8192 | 6 | 63 | 7 | 3 |
| 16384 | 7 | 127 | 15 | 7 |

- `BLS = 2^n` (n = 10 to 14)
- `BSH = n - 7`
- `BLM = 2^BSH - 1`
- `EXM = 2^(BSH-2) - 1` if DSM < 256
- `EXM = 2^(BSH-3) - 1` if DSM ≥ 256

**AL0/AL1 directory entries per bit set:**

| BLS | Directory entries per bit |
|-----|--------------------------|
| 1024 | 32 |
| 2048 | 64 |
| 4096 | 128 |
| 8192 | 256 |
| 16384 | 512 |

- `CKS = (DRM+1)/4` if drive media is removable; `CKS = 0` if fixed.
- `OFF` = number of reserved system tracks.
- `ALV` size = `(DSM/8)+1` bytes.
- `CSV` size = `CKS` bytes.

### Apple CP/M Disk Formats — DPB Comparison

| Physical format | A: 13-sect | B: 16-sect | C: 80-trk 16-sec 2-side | D: 8" SSSD |
|----------------|-----------|-----------|------------------------|-----------|
| Bytes/sector | 256 | 256 | 256 | 128 |
| Sectors/track | 13 | 16 | 16 | 26 |
| Tracks | 35 | 35 | 80 | 77 |
| Heads | 1 | 1 | 2 | 1 |
| **SPT** | 26 | 32 | 32 | 26 |
| **BSH** | 3 | 3 | 4 | 3 |
| **BLM** | 7 | 7 | 15 | 7 |
| **EXM** | 0 | 0 | 0 | 0 |
| **DSM** | 103 | 127 | 313 | 242 |
| **DRM** | 47 | 63 | 255 | 63 |
| **AL0** | C0H | C0H | F0H | C0H |
| **AL1** | 0 | 0 | 0 | 0 |
| **CKS** | 12 | 16 | 64 | 16 |
| **OFF** | 3 | 3 | 3 | 2 |
| Block size (bytes) | 1024 | 1024 | 2048 | 1024 |
| Dir entries | 48 | 64 | 256 | 64 |
| Disk size (KBytes, excl. sys tracks) | 104 | 128 | 628 | 243 |
| Disk size (KBytes, incl. sys tracks) | 113.75 | 140 | 640 | 250 |

> **Format notes:**
> - **A:** SoftCard 13-sector format — used only briefly on early systems. 104K per diskette.
> - **B:** 16-sector Apple CP/M format — THE standard Apple CP/M format, used by SoftCard and all subsequent Apple CP/M systems. 128K per diskette.
> - **C:** 80-track double-sided, 16 sectors/track; 160 virtual tracks to the BIOS. 628K per diskette.
> - **D:** Standard CP/M 8" SSSD — provided for comparison.

---

*Last modified: 2019/09/30 — MG's Apple II Site*
