module MUX (
    input logic sel,
    input logic [7:0] A, B,
    output logic [7:0] Out
);
    always @(*) begin
        if (sel)
            Out = A;
        else
            Out = B;
    end
endmodule