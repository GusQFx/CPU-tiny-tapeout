# SPDX-FileCopyrightText: © 2026 Tiara Ramirez
# SPDX-License-Identifier: Apache-2.0
#
# Drives the CPU through the real Tiny Tapeout pinout (ui_in / uo_out /
# uio_in / rst_n), the same wrapper that gets hardened and shipped. Every
# program here is hand-verified against the opcode encoding in
# modules/control.sv, re-addressed to fit the production MEM_DEPTH=8 (the
# standalone SystemVerilog testbenches -- testbench/tt_wrapper_tb.sv,
# testbench/CPU_tb.sv and the 22 unit_tests/test_*.sv -- use a larger depth
# for convenience and are unaffected by this).
#
# LD/ST are single-byte instructions now: the address (0-7) is embedded
# directly in the opcode (LD_A/LD_B/LD_C, ST_A/ST_B/ST_C each get their own
# opcode family), instead of being fetched as a separate second byte. No
# instruction needs more than one byte except the conditional/unconditional
# jumps (Jcc), which still take a second byte for the target address.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer

PROGRAM_MODE = 1 << 0
PROGRAM_WR = 1 << 1


async def start_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())


async def reset(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    await Timer(1, unit="ns")  # release away from the edge the FSM samples
    dut.rst_n.value = 1


async def flash_program(dut, program):
    """Loads `program` (a list of bytes) into memory via program_mode/program_wr,
    then resets so the PC goes back to 0 before execution starts. Mirrors the
    exact bit-timing verified in testbench/tt_wrapper_tb.sv: values are set
    mid-cycle (right after a posedge), not at the edge that consumes them --
    going through the wrapper needs that extra propagation margin.
    """
    dut.uio_in.value = PROGRAM_MODE
    for byte in program:
        await RisingEdge(dut.clk)
        dut.ui_in.value = byte
        dut.uio_in.value = PROGRAM_MODE | PROGRAM_WR
        await FallingEdge(dut.clk)
        dut.uio_in.value = PROGRAM_MODE
    dut.uio_in.value = 0
    dut.ui_in.value = 0

    await reset(dut)


@cocotb.test()
async def test_load_add_out(dut):
    """LD_A / LD_B / ADD B / OUT A / HLT -- same instructions verified by
    testbench/tt_wrapper_tb.sv. With only 8 words to work with, A and B both
    load from the same data byte (addr 6); A+B=8 still proves the
    LD-from-memory and register-to-register ADD paths both work."""
    await start_clock(dut)
    await reset(dut)

    program = [0] * 8
    program[0] = 0x0E  # LD_A #6 (data 4)
    program[1] = 0x16  # LD_B #6 (data 4)
    program[2] = 0x39  # ADD B    -> A = 4+4 = 8
    program[3] = 0x60  # OUT A
    program[4] = 0xFF  # HLT
    program[6] = 4

    await flash_program(dut, program)
    await ClockCycles(dut.clk, 60)

    assert dut.uo_out.value == 8, f"expected uo_out=8, got {int(dut.uo_out.value)}"


@cocotb.test()
async def test_store_load_roundtrip(dut):
    """IN A (captures a known external value) then ST_A / LD_B -- proves
    memory is actually read/written, not just wired through. The store
    target (addr 6) is never fetched as an instruction (the CPU halts at
    addr 4), so writing over it at runtime is safe."""
    await start_clock(dut)
    await reset(dut)

    program = [0] * 8
    program[0] = 0x68  # IN A     (A <- external_input)
    program[1] = 0x26  # ST_A #6  (scratch, never used as code)
    program[2] = 0x16  # LD_B #6  (re-read what ST just wrote)
    program[3] = 0x61  # OUT B
    program[4] = 0xFF  # HLT
    # program[6] left as 0: overwritten by ST before it's ever read as code

    await flash_program(dut, program)

    dut.ui_in.value = 7  # value IN will capture
    await ClockCycles(dut.clk, 60)

    assert dut.uo_out.value == 7, f"expected uo_out=7, got {int(dut.uo_out.value)}"


@cocotb.test()
async def test_conditional_jump_jz(dut):
    """SUB A (A-A=0, zero=1 regardless of A's value, so no LD is needed to
    set it up) then JZ -- verifies flags actually feed back into the jump
    decision. The trap path (fall-through) outputs A untouched (0); the
    correct path (jump target) NOTs A first, so the two are unambiguous."""
    await start_clock(dut)
    await reset(dut)

    program = [0] * 8
    program[0] = 0x40                 # SUB A      A=0-0=0, zero=1
    program[1], program[2] = 0x71, 5  # JZ #5      should jump to the correct path
    program[3] = 0x60                 # TRAP: OUT A (bad=0, should not execute)
    program[4] = 0xFF                 # TRAP: HLT
    program[5] = 0x78                 # CORRECT: NOT A -> A = 0xFF = 255
    program[6] = 0x60                 # CORRECT: OUT A
    program[7] = 0xFF                 # CORRECT: HLT

    await flash_program(dut, program)
    await ClockCycles(dut.clk, 60)

    assert dut.uo_out.value == 255, f"expected uo_out=255, got {int(dut.uo_out.value)}"


@cocotb.test()
async def test_halt_stops_cpu(dut):
    """HLT must actually freeze the CPU. Trap: if it doesn't, execution falls
    through to a NOT A + OUT A that would overwrite the output with ~55."""
    await start_clock(dut)
    await reset(dut)

    program = [0] * 8
    program[0] = 0x68  # IN A       (A <- external_input)
    program[1] = 0x60  # OUT A      output=55
    program[2] = 0xFF  # HLT
    program[3] = 0x78  # TRAP (should never execute): NOT A (bad=200)
    program[4] = 0x60  # TRAP: OUT A
    program[5] = 0xFF  # TRAP: HLT

    await flash_program(dut, program)

    dut.ui_in.value = 55  # value IN will capture
    await ClockCycles(dut.clk, 60)

    assert dut.uo_out.value == 55, f"expected uo_out=55, got {int(dut.uo_out.value)}"


@cocotb.test()
async def test_external_input(dut):
    """IN A -- captures external_input (ui_in) through the wrapper's dedicated
    input pins, then OUT A puts it back out on uo_out."""
    await start_clock(dut)
    await reset(dut)

    program = [0] * 8
    program[0] = 0x68  # IN A
    program[1] = 0x60  # OUT A
    program[2] = 0xFF  # HLT

    await flash_program(dut, program)

    dut.ui_in.value = 123  # value IN will capture (ui_in is free once flashing is done)
    await ClockCycles(dut.clk, 60)

    assert dut.uo_out.value == 123, f"expected uo_out=123, got {int(dut.uo_out.value)}"
