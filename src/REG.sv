module REG (
    input logic clk,
    input logic reset,
    input logic [0:0]wr,
    input logic [7:0] Data_IN,
    output logic [7:0] Data_OUT = 0
);
    always_ff @(negedge clk) begin
        if (reset)
            Data_OUT = 7'b0;
        else if (wr)
            Data_OUT = Data_IN;
    end
endmodule