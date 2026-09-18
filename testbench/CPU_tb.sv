`timescale 1ns/1ps

module CPU_tb;
    reg clk = 0;
    reg reset = 0;
    reg program_mode = 0;
    reg program_wr = 0;
    reg [7:0] external_input = 0;
    wire [7:0] external_output;

    // MEM_DEPTH=64 to have room for addresses in the test;
    // the default value (16) is still what's used for the real layout.
    CPU #(.MEM_DEPTH(64)) dut (
        .clk(clk),
        .reset(reset),
        .program_mode(program_mode),
        .program_wr(program_wr),
        .external_input(external_input),
        .external_output(external_output)
    );

    always #5 clk = ~clk; // 10ns period

    // Test program: exercises the definitive instruction set
    // (see DESIGN.md for the full opcode table). LD/ST are single-byte
    // with the address embedded in the opcode (0-7), one opcode family per
    // destination/source register (LD_A/LD_B/LD_C, ST_A/ST_B/ST_C).
    //
    //   addr0:  JMP #8          header: skip the data words below
    //   addr2..7: data (see below)
    //   addr8:  LD_A #2         A=5
    //   addr9:  LD_B #3         B=3
    //   addr10: ADD B           A=5+3=8
    //   addr11: ST_A #4         mem[4]=8
    //   addr12: LD_C #4         C=8 (re-reads what ST just stored)
    //   addr13: SUB C           A=8-8=0, zero=1
    //   addr14: JZ #18          should jump (zero=1)
    //   addr16: JMP #40         TRAP: only reached if JZ didn't jump
    //   addr18: LD_A #5         A=0xF0
    //   addr19: LD_B #6         B=0x0F
    //   addr20: AND B           A=0xF0&0x0F=0x00, zero=1
    //   addr21: JNZ #40         TRAP: should not jump (zero=1 -> "not zero" is false)
    //   addr23: OR B            A=0x00|0x0F=0x0F
    //   addr24: XOR B           A=0x0F^0x0F=0x00
    //   addr25: NOT             A=~0x00=0xFF
    //   addr26: SHR             A=0xFF>>1=0x7F
    //   addr27: SHL             A=0x7F<<1=0xFE
    //   addr28: IN C            C <- external_input (=0x01, set by the testbench)
    //   addr29: ADD C           A=0xFE+0x01=0xFF
    //   addr30: OUT A           external_output <- 0xFF
    //   addr31: HLT
    //   addr40: LD_A #7         TRAP (destination of broken conditional jumps): A=99
    //   addr41: OUT A
    //   addr42: HLT
    //
    // Data: addr2=5, addr3=3, addr4=0 (scratch, overwritten by ST_A),
    //       addr5=0xF0, addr6=0x0F, addr7=99 (bad, for the trap)
    //
    // Expected result: 0xFF (255). If any conditional jump is broken, the
    // result falls into the trap and gives 99.
    reg [7:0] test_program [0:42];
    integer i;

    initial begin
        for (i = 0; i <= 42; i = i + 1)
            test_program[i] = 8'h00; // default filler: NOP

        test_program[0] = 8'h70; test_program[1] = 8'd8; // JMP #8
        test_program[2] = 8'd5;
        test_program[3] = 8'd3;
        test_program[4] = 8'd0;
        test_program[5] = 8'hF0;
        test_program[6] = 8'h0F;
        test_program[7] = 8'd99;

        test_program[8]  = 8'h0A; // LD_A #2
        test_program[9]  = 8'h13; // LD_B #3
        test_program[10] = 8'h39; // ADD B
        test_program[11] = 8'h24; // ST_A #4
        test_program[12] = 8'h1C; // LD_C #4
        test_program[13] = 8'h42; // SUB C
        test_program[14] = 8'h71; test_program[15] = 8'd18; // JZ #18
        test_program[16] = 8'h70; test_program[17] = 8'd40; // JMP #40 (trap)
        test_program[18] = 8'h0D; // LD_A #5
        test_program[19] = 8'h16; // LD_B #6
        test_program[20] = 8'h49; // AND B
        test_program[21] = 8'h72; test_program[22] = 8'd40; // JNZ #40 (trap)
        test_program[23] = 8'h51; // OR B
        test_program[24] = 8'h59; // XOR B
        test_program[25] = 8'h78; // NOT
        test_program[26] = 8'h7A; // SHR
        test_program[27] = 8'h79; // SHL
        test_program[28] = 8'h6A; // IN C
        test_program[29] = 8'h3A; // ADD C
        test_program[30] = 8'h60; // OUT A
        test_program[31] = 8'hFF; // HLT

        test_program[40] = 8'h0F; // LD_A #7 (trap: destination of broken jumps, bad=99)
        test_program[41] = 8'h60; // OUT A
        test_program[42] = 8'hFF; // HLT

        // Initial reset
        reset = 1;
        repeat (2) @(posedge clk);
        #1; // release the reset away from the edge, avoids a race with the FSM
        reset = 0;

        // Flash the program, byte by byte. Values are set mid-cycle (right
        // after a posedge), not exactly on the negedge that consumes them:
        // with the CPU's write enables gated by an extra AND (`wr & cpu_en`,
        // added when clock-gating was removed for STA), the old
        // negedge-first pattern loses the same-instant race and the byte
        // silently doesn't get written.
        program_mode = 1;
        for (i = 0; i <= 42; i = i + 1) begin
            @(posedge clk);
            external_input = test_program[i];
            program_wr = 1;
            @(negedge clk);
            program_wr = 0;
        end
        program_mode = 0;

        // Reset so the PC goes back to 0 before executing
        reset = 1;
        repeat (2) @(posedge clk);
        #1;
        reset = 0;

        // Fixed value that IN will capture (addr28). Left stable for the
        // rest of the run, since IN is only used once in this program.
        external_input = 8'h01;

        // Let the program run (each instruction can take up to 3 states,
        // jumps up to 4)
        repeat (100) @(posedge clk);

        if (external_output == 8'hFF)
            $display("PASS: external_output = %0d (expected 255)", external_output);
        else
            $display("FAIL: external_output = %0d (expected 255)", external_output);

        $finish;
    end

    initial begin
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, CPU_tb);
    end
endmodule
