`timescale 1ns/1ps

// Individual test: CMP reg -- flags <- A - reg, A is left untouched. Verified
// with a JZ afterward (A==B -> zero=1) while confirming A is still the
// original value (CMP must not write it).
module test_cmp;
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
        prog[2] = 8'd7;                  // data: 7 (for A)
        prog[3] = 8'd7;                  // data: 7 (for B)
        prog[4] = 8'd99;                 // data: bad

        prog[8]  = 8'h0A;                   // LD_A #2   A=7
        prog[9]  = 8'h13;                   // LD_B #3   B=7
        prog[10] = 8'h81;                   // CMP B     flags: zero=1, A stays=7
        prog[11] = 8'h71; prog[12] = 8'd16; // JZ #16    should jump
        prog[13] = 8'h0C;                   // TRAP: LD_A #4 (bad=99)
        prog[14] = 8'h60;                   // OUT A
        prog[15] = 8'hFF;                   // HLT
        prog[16] = 8'h60;                   // CORRECT: OUT A (A stays=7, CMP didn't touch it)
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

        if (external_output == 8'd7)
            $display("PASS CMP: external_output = %0d (expected 7)", external_output);
        else
            $display("FAIL CMP: external_output = %0d (expected 7)", external_output);

        $finish;
    end
endmodule
