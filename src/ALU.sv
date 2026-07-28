module ALU (
    input logic clk,
    input logic Op,
    input logic [7:0] A, 
    input logic [7:0] B,
    output logic [7:0] Out = 0
  );
  always_ff @(posedge clk) begin
    if (Op)
      Out = A - B;
    else
      Out = A + B;
  end

endmodule
