module MUX_3 (
    input logic [1:0] sel,
    input logic [7:0] A, B, C,
    output logic [7:0] Out
);
    always_comb  begin
        if (sel == 2'b00)
            Out = A;
        else if (sel == 2'b01)
            Out = B;
        else if (sel == 2'b10)
            Out = C;
        else
            Out = 8'b0;
    end
endmodule

