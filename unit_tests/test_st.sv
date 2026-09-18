`timescale 1ns/1ps

// Individual test: ST_A addr -- mem[addr] <- A (roundtrip: write with A, read back with B via LD_B)
module test_st;
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
        prog[2] = 8'd7;                  // data: 7

        prog[8]  = 8'h0A; // LD_A #2      A=7
        prog[9]  = 8'h24; // ST_A #4      mem[4]<-A
        prog[10] = 8'h14; // LD_B #4      B<-mem[4]
        prog[11] = 8'h61; // OUT B
        prog[12] = 8'hFF; // HLT

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
            $display("PASS ST: external_output = %0d (expected 7)", external_output);
        else
            $display("FAIL ST: external_output = %0d (expected 7)", external_output);

        $finish;
    end
endmodule
