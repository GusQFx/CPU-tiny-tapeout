module Testbench;
  logic clk = 1'b0;
  logic reset = 1'b0;
  logic [7:0] External_A = 8'b0;
  logic [7:0] External_B = 8'b0;
  logic [7:0] Input_Instruccion = 8'b0;
  logic [7:0] Out_ALU;

  always #1 clk = ~clk;

  CPU cpu(
            .clk(clk),
            .reset(reset),
            .Input_A(External_A),
            .Input_B(External_B),
            .input_IR(Input_Instruccion),
            .ALU_Out_CPU(Out_ALU)
          );

  initial begin
    $dumpfile("build/dump.vcd");
    $dumpvars(0);

    External_A = 7;
    External_B = 5;

    #50 reset = 1'b1;
    #5 reset = 1'b0;

    External_A = 2;
    External_B = 8;

    #100 $finish;
  end


endmodule
