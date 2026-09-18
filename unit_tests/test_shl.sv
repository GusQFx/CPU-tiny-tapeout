`timescale 1ns/1ps

// Individual test: SHL -- A <- A << 1
module test_shl;
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

        prog[0] = 8'h70; prog[1] = 8'd8; // JMP #8
        prog[2] = 8'h0F;                 // data: 0x0F (15)

        prog[8] = 8'h0A; // LD_A #2   A=15
        prog[9] = 8'h79; // SHL       A=30
        prog[10] = 8'h60; // OUT A
        prog[11] = 8'hFF; // HLT

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

        if (external_output == 8'd30)
            $display("PASS SHL: external_output = %0d (expected 30)", external_output);
        else
            $display("FAIL SHL: external_output = %0d (expected 30)", external_output);

        $finish;
    end
endmodule
