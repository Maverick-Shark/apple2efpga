# The Microsoft SoftCard for the Apple II: Getting Two Processors to Share the Same Memory

**Author:** Raymond Chen  
**Published:** November 4, 2025  
**Source:** [The Old New Thing – Microsoft Dev Blogs](https://devblogs.microsoft.com/oldnewthing/20251104-00/?p=111758)

---

The [Microsoft Z-80 SoftCard](https://en.wikipedia.org/wiki/Z-80_SoftCard) was a plug-in expansion card for the Apple II that added the ability to run CP/M software. According to Wikipedia, it was Microsoft's first hardware product and in 1980 was the single largest revenue source for the company.

CP/M runs on an 8080 processor, but the Apple II has a 6502 processor. So how can you run CP/M on an Apple II? Answer: The card comes with its own 8080-compatible processor, the Zilog Z80, which was arguably better than the 8080 for [a bunch of reasons given on its Wikipedia page](https://en.wikipedia.org/wiki/Zilog_Z80).[^1]

Great, you now have a processor. But what happens to the old 6502 processor? Ideally, you would just shut it off, but you can't go cold turkey because some things still had to be handled by the 6502.[^2] [Nicole Branagan digs deeper into the story of how the two processors coexist](https://nicole.express/2020/nicole-gets-a-real-computer.html). The idea is that the SoftCard tells the 6502 that it's doing DMA, so the 6502 pauses and waits for the DMA to complete. However, you can't leave the 6502 paused for too long or its internal registers degrade and lose their values.

The solution is to take advantage of the Z80's REFRESH line, which the processor uses to signal that it's not accessing memory right now (because it's [decoding an instruction](http://www.piclist.com/techref/mem/dram/slide4.html)). This tells external memory refresh circuitry that it can run and keep the RAM values refreshed so that *they* don't degrade and lose their values.

On the Apple II, memory refreshing is done by the video circuitry, so there is no need for a dedicated REFRESH signal. The SoftCard uses this signal to allow the 6502 to execute a tiny little bit. (Presumably it is sitting in a spin loop waiting to be woken.) This keeps the 6502's registers refreshed.

When the SoftCard needs the 6502 to do actual work, it can update some memory to tell the 6502, "Break out of your spin loop and do something for me, then let me know the answer and go back to the spin loop." The Z80 then goes to sleep until it gets an answer from the 6502.

## Memory Map Remapping

Another wrinkle in the way that the 6502 and Z80 shared memory is in the memory map. Both the Z80 and 6502 consider the first 256 bytes of memory to be special and want to use it for different things. Furthermore, CP/M programs expect to be loaded at `$0100`, but the 6502 hard-codes its CPU stack to live in the range `$0100–$01FF`. There are other obstacles in the low part of the Apple II memory map:

- The Apple II system monitor uses `$0200–$02FF` as its keyboard input buffer
- The bytes in the range `$03F0–$03FF` are used to hold interrupt vectors
- The text video frame buffer goes from `$0400–$07FF` (there is a second text video frame buffer from `$0800–$0BFF`, but almost nobody uses it)
- The memory range from `$C000–$CFFF` is used by peripheral devices
- The memory range from `$D000–$FFFF` holds the Apple II monitor ROM, but can be replaced by RAM if you have the Language Card (a 16KB memory expansion card), except that the last few bytes `$FFFA–$FFFF` are used by the CPU as interrupt vectors

The solution is to remap the memory by putting address translation circuitry on the SoftCard, so that when the Z80 asks for memory address `$0000`, it actually gets physical memory `$1000`. The remapping is carefully arranged so that all of the Apple II's special reserved addresses get shuffled to the end of the Z80 memory map, and all of the Apple II's normal RAM occupies contiguous address space in the Z80 memory map starting at `$0000`.[^3]

### Memory Remapping Table

| 6502 Address | Usage (6502) | Physical Address | Z80 Address | Usage (Z80) |
|---|---|---|---|---|
| `$0000–$0FFF` | Special use | `$1000–$1FFF` | `$0000–$0FFF` | Normal RAM (contiguous, up to installed RAM) |
| `$1000–$1FFF` | Normal RAM | `$2000–$2FFF` | `$1000–$1FFF` | Normal RAM |
| `$2000–$2FFF` | Normal RAM | `$3000–$3FFF` | `$2000–$2FFF` | Normal RAM |
| `$3000–$3FFF` | Normal RAM | `$4000–$4FFF` | `$3000–$3FFF` | Normal RAM |
| `$4000–$4FFF` | Normal RAM | `$5000–$5FFF` | `$4000–$4FFF` | Normal RAM |
| `$5000–$5FFF` | Normal RAM | `$6000–$6FFF` | `$5000–$5FFF` | Normal RAM |
| `$6000–$6FFF` | Normal RAM | `$7000–$7FFF` | `$6000–$6FFF` | Normal RAM |
| `$7000–$7FFF` | Normal RAM | `$8000–$8FFF` | `$7000–$7FFF` | Normal RAM |
| `$8000–$8FFF` | Normal RAM | `$9000–$9FFF` | `$8000–$8FFF` | Normal RAM |
| `$9000–$9FFF` | Normal RAM | `$A000–$AFFF` | `$9000–$9FFF` | Normal RAM |
| `$A000–$AFFF` | Normal RAM | `$B000–$BFFF` | `$A000–$AFFF` | Normal RAM |
| `$B000–$BFFF` | Normal RAM | `$D000–$DFFF` | `$B000–$BFFF` | Expansion RAM (except last 6 bytes) |
| `$C000–$CFFF` | I/O space | `$E000–$EFFF` | `$C000–$CFFF` | I/O space |
| `$D000–$DFFF` | Expansion RAM | `$F000–$FFFF` | `$D000–$DFFF` | Expansion RAM |
| `$E000–$EFFF` | Expansion RAM | `$C000–$CFFF` | `$E000–$EFFF` | (remapped) |
| `$F000–$FFFF` | Special use | `$0000–$0FFF` | `$F000–$FFFF` | Special use |

## Documentation

The SoftCard manual contained lots of details on how to write code for it. For example, it included [instructions on how to call into a 6502 subroutine from Z80](https://archive.org/details/mscard_software_hardware_details/page/n25/mode/2up) and had [a chart showing how the memory was remapped for the Z80](https://archive.org/details/mscard_software_hardware_details/page/n5/mode/2up). It even included the Z80 processor reference manual, listing all the instructions.

---

[^1]: I don't know where the hyphen in *Z-80* came from.

[^2]: In many places, I/O was handled by timing loops, so if you wanted to access, say, the game paddles, you had to let the 6502 do the I/O with its precise software timing loops.

[^3]: There were also two high resolution graphics frame buffers, one at `$2000–$3FFF`, and another at `$4000–$5FFF`. These were right in the middle of the Z80 memory map, but in practice it wasn't a problem because CP/M was a text-mode operating system, so the programs you were running didn't try to do graphics anyway.
