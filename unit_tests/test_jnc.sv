`timescale 1ns/1ps

// Individual test: JNC addr -- jumps if carry=0. Forced with ADD A on a
// small value (2+2=4, doesn't overflow -> carry=0).
module test_jnc;
    reg clk = 0;
    reg reset = 0;
    reg program_mode = 0;
    reg program_wr = 0;
    reg [7:0] external_input = 0;
    wire [7:0] external_output;

    CPU #(.MEM_DEPTH(32)) dut (
        .clk(clk), .reset(reset), .program_mode(program_mode), .program_wr(program_wr),
        .external_input(external_input), .external_output(external_output)
    );

    always #5 clk = ~clk;

    reg [7:0] prog [0:31];
    integer i;

    initial begin
        for (i = 0; i <= 31; i = i + 1) prog[i] = 8'h00;

        prog[0] = 8'h70; prog[1] = 8'd8; // JMP #8 (header)
        prog[2] = 8'd2;                  // data: 2
        prog[3] = 8'd99;                 // data: bad
        prog[4] = 8'd42;                 // data: good

        prog[8]  = 8'h0A;                   // LD_A #2   A=2
        prog[9]  = 8'h38;                   // ADD A     A=4, carry=0
        prog[10] = 8'h74; prog[11] = 8'd15; // JNC #15   should jump
        prog[12] = 8'h0B;                   // TRAP: LD_A #3 (bad=99)
        prog[13] = 8'h60;                   // OUT A
        prog[14] = 8'hFF;                   // HLT
        prog[15] = 8'h0C;                   // CORRECT: LD_A #4 (good=42)
        prog[16] = 8'h60;                   // OUT A
        prog[17] = 8'hFF;                   // HLT

        reset = 1; repeat (2) @(posedge clk); #1; reset = 0;

        program_mode = 1;
        for (i = 0; i <= 31; i = i + 1) begin
            @(posedge clk);
            external_input = prog[i];
            program_wr = 1;
            @(negedge clk);
            program_wr = 0;
        end
        program_mode = 0;

        reset = 1; repeat (2) @(posedge clk); #1; reset = 0;

        repeat (40) @(posedge clk);

        if (external_output == 8'd42)
            $display("PASS JNC: external_output = %0d (expected 42)", external_output);
        else
            $display("FAIL JNC: external_output = %0d (expected 42)", external_output);

        $finish;
    end
endmodule
