# CPU Tiny Tapeout — design log

Educational 8-bit CPU in SystemVerilog, single shared bus, SAP-style
architecture. Target: submit it to the Tiny Tapeout IHP 26b shuttle
(closes 2026-09-21).

This document is a running log of the state and decisions made so far.
It lives at the repo root of `ttihp-verilog-template`: `DESIGN.md`.

## File structure

```
ttihp-verilog-template/
├── info.yaml                  Tiny Tapeout project metadata (required for submission)
├── src/                       everything Tiny Tapeout's synthesis flow reads, per info.yaml's source_files
│   ├── tt_um_tiarinix_ttihp_verilog_template.sv   TT wrapper (top_module)
│   ├── CPU.sv                 CPU top-level module, wires everything together
│   └── modules/
│       ├── alu.sv                8-bit ALU, 8 operations
│       ├── control.sv            control unit (FSM + decoder)
│       ├── memory.sv             program/data memory (Von Neumann)
│       ├── mux.sv                generic parameterized mux (N inputs)
│       ├── plus_one_adder.sv     combinational incrementer for the PC
│       ├── register.sv           generic WIDTH-bit register
│       └── tristate_buffer.sv    DEAD CODE: superseded by the OR-masked
│                                  `assign bus = ...` in CPU.sv (internal
│                                  tri-state 'z isn't synthesizable in a
│                                  standard-cell flow); nothing instantiates
│                                  it anymore. Still listed in info.yaml's
│                                  source_files (harmless -- Yosys never
│                                  elaborates an uninstantiated module into
│                                  the design) but worth deleting for
│                                  clarity if there's a spare minute.
├── testbench/
│   ├── CPU_tb.sv              main testbench (drives CPU.sv directly)
│   └── tt_wrapper_tb.sv       testbench through the TT wrapper's pinout
├── unit_tests/                 one self-contained testbench per instruction
│                               (see "Per-instruction individual tests" below).
│                               Deliberately named `unit_tests/`, not `test/`,
│                               to avoid colliding with Tiny Tapeout's own
│                               `test/` (the cocotb harness: `test/Makefile` +
│                               `test/tb.v` + `test/test.py`, which the
│                               ttihp-verilog-template already ships and CI
│                               (`test.yaml`) actually runs).
├── test/                       Tiny Tapeout's official cocotb harness
│                               (Makefile, tb.v, test.py, requirements.txt) —
│                               this is what test.yaml runs in CI.
└── DESIGN.md                  this file
```

**No `` `include `` anywhere in `src/`.** Every file under `src/` is a
standalone compilation unit, listed explicitly both in `info.yaml`'s
`source_files` and in `test/Makefile`'s `PROJECT_SOURCES` and
`unit_tests/run_all.sh`'s compile command. This mirrors exactly how Tiny
Tapeout's synthesis flow consumes a multi-file design (it reads each listed
file directly, it doesn't run a preprocessor `` `include `` chain from a
single entry point) — so there's no divergence between "how we simulate
locally" and "how it actually gets built".

## Architecture

- One shared 8-bit bus across all blocks (`bus` in `CPU.sv`), built as an
  OR of AND-masked driver terms (`assign bus = ({8{en1}} & d1) | ...`),
  not tri-state `'z` — internal tri-state isn't synthesizable in a
  standard-cell ASIC flow (only dedicated I/O pads support it), so the
  original `TRIStateBuffer`-based bus was replaced with this before any
  real synthesis attempt. `modules/tristate_buffer.sv` is dead code now
  (see the file structure note above).
- Single memory for program and data (Von Neumann), depth parameterized
  via `MEM_DEPTH` (default 16; the production wrapper currently uses 14;
  the general-purpose testbench uses 64 for headroom — see the area-cut
  section below for why LD/ST specifically can't address past word 7
  regardless of this value).
- 3-state instruction cycle for most instructions, 4-state for jumps, in
  `control.sv`:
  1. `FETCH1`  — `IR <- mem[PC]`, `PC <- PC+1`
  2. `FETCH2`  — **only for `Jcc`** (jumps): reads the target address byte
     and resolves the jump (`PC <- target` if taken, else `PC <- PC+1`).
     Every other instruction skips straight to `EXECUTE` — see the
     area-cut section for why.
  3. `EXECUTE` — decodes `IR` and triggers the operation (ALU, etc.)
  4. `STORE`   — memory access or register write, when applicable
- A single real clock (`clk`) drives every flip-flop. Registers freeze
  during `HLT`/flashing via a synchronous write-enable (`wr & cpu_en` /
  `wr & mem_pc_en` in `CPU.sv`), not by gating the clock itself — an
  earlier version gated the clock (`cpu_clk = clk & ~halted & ...`),
  which created a second, undeclared clock tree that STA couldn't
  reconcile (an unfixable ~10ns hold violation). `halted`'s own reset is
  synchronous too, to match (Verilator flagged the previous mix of
  synchronous and asynchronous use of the same `reset` net as
  `SYNCASYNCNET`).
- 3 general-purpose registers (A-C; cut back from 5/A-E — see the
  area-cut section). `CONTROL` doesn't expose a `wr` per register: it
  exposes `reg_dest_sel[2:0]` + `reg_dest_wr`, and `CPU.sv` decodes the
  per-register enable right there. Same pattern already used by
  `alu_sel_a/b` and `bus_out_sel` (a selector into an N-input mux).
- During `program_mode` (flashing), `external_input` writes directly to
  `MEM.In` and `MEM.Addr` is forced to `PC`, bypassing both the bus and
  the register file — it's a path separate from the normal datapath.
- `halted` (in `CPU.sv`) permanently freezes the CPU (via the enables
  above) once `HLT` executes, until the next `reset`.

## Area cut: registers 5→3, LD/ST → single-byte embedded address

Trimmed down from the original 5-register, 2-byte-LD/ST design because
the synthesized area didn't fit the target tile even after aggressive
OpenLane placement-density tuning (see `src/config.json`). Two changes,
both in `modules/control.sv` and `CPU.sv`:

1. **Registers D and E removed.** Back to A/B/C only — 2 fewer 8-bit
   registers, and the `alu_sel_a/b`/`bus_out_sel` muxes shrink from 5
   inputs to 3.
2. **`LD`/`ST` are single-byte now**, with the address embedded directly
   in the low 3 bits of the opcode (`ir_out[2:0]`, 0-7) instead of being
   fetched as a separate second byte. This halves their footprint in any
   program that uses them (previously the majority of most programs'
   bytes) and removes the `ADDR` register entirely (nothing loads it
   anymore — `mem_addr_sel` now picks between the embedded address and
   `PC` directly, no register in between).

   A 3-bit field can't hold both a register choice *and* an address, so
   instead of picking one, `LD`/`ST` each got **one opcode family per
   register** (`LD_A`/`LD_B`/`LD_C`, `ST_A`/`ST_B`/`ST_C` — 6 families
   instead of 2) — there's plenty of spare opcode space (16 of 32
   possible 5-bit families used) so no register lost addressability or
   became unreachable. The trade-off that's real: **`LD`/`ST` can only
   reach memory words 0-7**, regardless of `MEM_DEPTH` — a 3-bit field
   only ever addresses 8 words. Data constants/scratch space need to live
   in the first 8 words; code and jump targets aren't affected (`Jcc`
   still fetches a full 8-bit address byte, unchanged).
   Jumps were deliberately **not** folded into this scheme: they already
   need a condition-code field (7 values) *and* an address, which doesn't
   fit in one byte without also cutting condition coverage — not worth it
   for the marginal gain, since jumps are typically a minority of a
   program's bytes compared to `LD`/`ST`.

Updated instruction set (family = `ir_out[7:3]`, register/condition/
address field = `ir_out[2:0]`). Registers: A=000, B=001, C=010 (011-111
invalid → fall into the "unknown instruction" `default`).

| Opcode | Mnemonic | Bytes | Effect |
|---|---|---|---|
| `0x00` | `NOP` | 1 | nothing |
| `0x08-0x0F` | `LD_A addr` | 1 | `A <- mem[addr]` (addr: 0-7) |
| `0x10-0x17` | `LD_B addr` | 1 | `B <- mem[addr]` |
| `0x18-0x1F` | `LD_C addr` | 1 | `C <- mem[addr]` |
| `0x20-0x27` | `ST_A addr` | 1 | `mem[addr] <- A` |
| `0x28-0x2F` | `ST_B addr` | 1 | `mem[addr] <- B` |
| `0x30-0x37` | `ST_C addr` | 1 | `mem[addr] <- C` |
| `0x38-0x3C` | `ADD reg` | 1 | `A <- A + reg` |
| `0x40-0x44` | `SUB reg` | 1 | `A <- A - reg` |
| `0x48-0x4C` | `AND reg` | 1 | `A <- A & reg` |
| `0x50-0x54` | `OR reg` | 1 | `A <- A \| reg` |
| `0x58-0x5C` | `XOR reg` | 1 | `A <- A ^ reg` |
| `0x60-0x64` | `OUT reg` | 1 | `external_output <- reg` |
| `0x68-0x6C` | `IN reg` | 1 | `reg <- external_input` |
| `0x70` | `JMP addr` | 2 | `PC <- addr` (unconditional) |
| `0x71` | `JZ addr` | 2 | jumps if `zero` |
| `0x72` | `JNZ addr` | 2 | jumps if `~zero` |
| `0x73` | `JC addr` | 2 | jumps if `carry` |
| `0x74` | `JNC addr` | 2 | jumps if `~carry` |
| `0x75` | `JN addr` | 2 | jumps if `negative` |
| `0x76` | `JO addr` | 2 | jumps if `overflow` |
| `0x78` | `NOT` | 1 | `A <- ~A` |
| `0x79` | `SHL` | 1 | `A <- A << 1` |
| `0x7A` | `SHR` | 1 | `A <- A >> 1` |
| `0x80-0x84` | `CMP reg` | 1 | `flags <- A - reg` (A untouched) |
| `0xFF` | `HLT` | 1 | stops the CPU |

**Other design decisions (unchanged from before):**
- Accumulator-style ALU: every ALU operation is `A <- A OP reg`, it never
  writes to another destination register. Avoids needing a second
  "destination register" field per opcode.
- `CMP` reuses `SUB`'s path (same `alu_op`, same `reg_f_wr=1`) but doesn't
  do `alu_out_en`/`reg_dest_wr` in `STORE` — the result is discarded, only
  the flags remain.
- Every instruction in the ALU family
  (`ADD/SUB/AND/OR/XOR/NOT/SHL/SHR/CMP`) sets `reg_f_wr=1` in `EXECUTE`, so
  conditional jumps have real data to evaluate.
- `IN` reuses the existing `reg_ext_in` → bus path: in `EXECUTE` it does
  `ext_in_wr=1` (captures `external_input`), in `STORE` it does
  `ext_in_en=1` + writing the destination register (same pattern `STORE`
  uses for everything else).
- Conditional jumps resolve in `FETCH2`: if the condition isn't met, it
  simply does `PC <- PC+1` instead of `PC <- bus`.

**Further cuts not yet done, if more area is still needed:** shrink
`FLAGS` from 8 bits to 4 (only carry/negative/zero/overflow are ever
used — free win, no functional loss); drop the `reg_ext_in` staging
register and tristate `external_input` straight onto the bus for `IN`
(saves 8 flip-flops, small risk to the input's synchronous-capture
margin). Registers/memory-depth are the two biggest area levers in a
design this size (flip-flops and memory arrays dominate over
combinational control logic) — see the chat history's area-cut analysis
for the full reasoning, including why a real SRAM macro was ruled out
(it's the size of an entire tile on its own).

## Tiny Tapeout wrapper

`src/tt_um_tiarinix_ttihp_verilog_template.sv` adapts TT's fixed pinout
to `CPU.sv`'s own port, without touching the datapath:

| TT | CPU.sv | Note |
|---|---|---|
| `clk` | `clk` | direct |
| `rst_n` (active low) | `reset` (active high) | `wire reset = ~rst_n;` |
| `ui_in[7:0]` | `external_input` | direct, 8 dedicated pins |
| `uo_out[7:0]` | `external_output` | direct, 8 dedicated pins |
| `uio_in[0]` | `program_mode` | from the bidirectional pins, as input |
| `uio_in[1]` | `program_wr` | same |
| `uio_out`, `uio_oe` | — | fixed at `8'h00` (no bidirectional outputs used) |
| `ena` | — | unused, grouped into an `_unused` wire together with `uio_in[7:2]` so the linter doesn't complain |

Verified with `testbench/tt_wrapper_tb.sv` (a minimal program that fits
the real 14-word `MEM_DEPTH` the production wrapper uses): `PASS: uo_out
= 8`. Deliberately confirmed that inverting `rst_n` actually matters
(tested with `reset = rst_n` without inverting, got `FAIL: uo_out = 0`,
then restored).

**Timing detail worth keeping in mind:** an early attempt at this
testbench failed because it changed `program_wr`/`ui_in` at the exact
same clock edge that consumes them. Going through one extra level of
hierarchy (bit-select → wrapper port → CPU port) needs more propagation
margin than that pattern leaves. Fixed by setting the values mid-cycle
(right after a `posedge`) instead of exactly on the `negedge` that
consumes them. This turned out to be one instance of a *general* issue —
see "Two real bugs found while re-verifying after the area cut" below —
not something specific to the wrapper's extra hierarchy after all.

## Two real bugs found while re-verifying after the area cut

Re-running the full test suite after the registers/LD-ST rewrite (and
after pulling in the clock-gating/reset-style fixes from a parallel
session — see the architecture notes above) surfaced two bugs that were
**not** caused by the area cut itself, but by that clock-gating removal.
They'd have silently broken every program on real hardware.

1. **Flashing silently wrote nothing, for every testbench.** The old
   negedge-first flashing pattern (`@(negedge clk); set values;
   program_wr=1; @(posedge clk); program_wr=0;`) relies on the testbench's
   stimulus and `MEM`'s own write landing in the same simulation instant —
   a same-edge race that Icarus resolves consistently in Icarus's favor
   *only* up to a certain amount of intervening propagation. Once clock
   gating was replaced with `wr & cpu_en`/`wr & mem_pc_en` (one extra
   AND-gate hop on every write-enable — see the architecture section),
   that was enough extra delay to flip the race the other way: `mem[]`
   stayed `x` after "flashing" completed. Symptom looked identical to a
   dead CPU (PC stuck at 0, `ir_out` never leaves `xx`). Fix: same as the
   wrapper's earlier fix — set stimulus values mid-cycle, right after a
   `posedge`, not on the `negedge` that consumes them. Applied to every
   flashing loop: `testbench/CPU_tb.sv`, `testbench/tt_wrapper_tb.sv`, and
   all 22 `unit_tests/test_*.sv`.
2. **`jump_taken` in `control.sv` latched `X` forever.** It was a `reg`
   driven by a `case (field)` inside `always @(*)`. `field` (`ir_out[2:0]`)
   defaults to `0` (`ir_out`'s reset value) — which is also the encoding
   for `COND_ALWAYS` (unconditional jump). The very first time a real
   `JMP` was fetched, `field` was *already* `0` from before (nothing
   "changed" from the block's point of view), so the `always @(*)` never
   re-triggered, and `jump_taken` stayed at its uninitialized `X` from
   time 0 — which `if (jump_taken)` treats as false, so the CPU silently
   fell through instead of jumping. Every program in the whole suite uses
   an unconditional `JMP` at the very top (to skip over the data bytes
   placed in the first few words), so this broke essentially everything,
   not just the jump-specific tests. Fix: rewrote `jump_taken` as a plain
   `assign` (nested ternary) instead of an `always@(*)`/`case`-driven
   `reg` — a continuous assignment has no such re-evaluation ambiguity.

Both were caught by tracing internal signals (`$monitor` on `state`,
`ir_out`, `family`, `field`, `jump_taken`, `pc_out`, ...) against a
hand-worked-out expected trace, the same technique used earlier in this
project's debugging history.

## `info.yaml`

Filled in at the repo root against the `ttihp-verilog-template` schema.
Notable choices:
- `language: "SystemVerilog"` (the source uses `logic`, `always_comb`,
  `always_ff`, not plain Verilog). LibreLane's Yosys synthesis step reads
  Verilog files with `-sv` by default, so this subset (no interfaces,
  packages, or other advanced SV features) synthesizes without extra
  configuration.
- `clock_hz: 0` — honest placeholder, since there's been no timing closure
  against a target frequency yet (see the synthesis-check pending item).
- `tiles: "1x1"` — default, unvalidated against real area (the reason for
  the area-cut work above).
- `pinout` documents the mapping already described in the wrapper section
  above (`ui[0..7]` → `external_input`, `uo[0..7]` → `external_output`,
  `uio[0]`/`uio[1]` → `program_mode`/`program_wr`, rest of `uio` blank).
- `source_files` lists every file under `src/` explicitly, matching
  `test/Makefile`'s `PROJECT_SOURCES`.

## Per-instruction individual tests

`unit_tests/` has one file per instruction (22 total: `test_nop.sv`,
`test_ld.sv`, `test_st.sv`, `test_add.sv`, `test_sub.sv`, `test_and.sv`,
`test_or.sv`, `test_xor.sv`, `test_out.sv`, `test_in.sv`, `test_jmp.sv`,
`test_jz.sv`, `test_jnz.sv`, `test_jc.sv`, `test_jnc.sv`, `test_jn.sv`,
`test_jo.sv`, `test_not.sv`, `test_shl.sv`, `test_shr.sv`, `test_cmp.sv`,
`test_hlt.sv`), each self-contained: it instantiates `CPU` directly
(without going through the TT wrapper), with its own minimal program and
its own `PASS`/`FAIL`. `unit_tests/run_all.sh` compiles and runs all of
them and prints a summary (`./unit_tests/run_all.sh` from the root).
Current status: **22/22 PASS**.

Conditional jumps (`JZ/JNZ/JC/JNC/JN/JO`) each use their own trap (same as
`JMP` and `CMP`): if the jump doesn't do what it's supposed to, the result
falls into a "bad" value (99) instead of the expected one (42). Verified
that `JC` (previously without dedicated verification) actually catches
breakage — forced `jump_taken=0` for that condition, got
`FAIL: external_output = 99` as expected, and restored it. `JNC/JN/JO`
share the same mechanism/`case` as `JC`, so they're covered by the same
kind of trap even though they weren't individually broken one by one.

## Official Tiny Tapeout test (`test/test.py`)

Re-encoded to match the area-cut opcode table (`LD_A`/`LD_B`/`ST_A`/etc.
are now single-byte; the old 2-byte `LD reg, addr` bytes it used are
stale). Covers the same five cases as before (load+add+out, store/load
roundtrip, a conditional-jump trap, HLT actually halting, external input),
each program now fits in the production `MEM_DEPTH=8`-sized layout
without needing a "jump over the data" header, since single-byte `LD`/`ST`
no longer eat the space a 2-byte version needed. **Not executed in this
session** (cocotb isn't installed in this environment) — hand-verified
byte-by-byte against the same family/field formulas already proven
correct by `unit_tests/` and `testbench/CPU_tb.sv`, but worth an actual
`make` run wherever cocotb is available before trusting it fully.
