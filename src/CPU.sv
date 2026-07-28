module CPU (
    input logic [0:0] clk, reset,
    input logic [7:0] Input_A, Input_B,
    input logic [7:0] input_IR,
    output logic [7:0] ALU_Out_CPU
  );

  logic [7:0] A, B, IR, PC, Input_Reg_A, Input_Reg_B, Mem_Data_OUT, ALU_Out;
  logic [0:0] we_REG_A, we_REG_B;
  logic [1:0] MUX_A_sel, MUX_B_sel;
  logic [0:0] ALU_Op;
  logic [0:0] wr_IR;
  logic [0:0] Inc_PC;
  logic  wr_ALU_Out;

  REG RegA(
        .clk(clk),
        .reset(reset),
        .wr(we_REG_A),
        .Data_IN(Input_Reg_A),
        .Data_OUT(A)
      );

  REG RegB(
        .clk(clk),
        .reset(reset),
        .wr(we_REG_B),
        .Data_IN(Input_Reg_B),
        .Data_OUT(B)
      );

  REG RegIR(
        .clk(clk),
        .reset(reset),
        .wr(wr_IR),
        .Data_IN(Mem_Data_OUT),
        .Data_OUT(IR)
      );

  REGPC RegPC(
        .clk(clk),
        .reset(reset),
        .wr(Inc_PC),
        .Data_IN(PC),
        .Data_OUT(PC)
      );

  REG ALU_salida(
        .clk(clk),
        .reset(reset),
        .wr(wr_ALU_Out),
        .Data_IN(ALU_Out),
        .Data_OUT(ALU_Out_CPU)
      );

  ALU alu(
        .clk(clk),
        .Op(ALU_Op),
        .A(A),
        .B(B),
        .Out(ALU_Out)
      );

  MUX_3 MUX_3_A(
          .sel(MUX_A_sel),
          .A(Input_A),
          .B(ALU_Out_CPU),
          .C(Mem_Data_OUT),
          .Out(Input_Reg_A)
        );

  MUX_3 MUX_3_B(
          .sel(MUX_B_sel),
          .A(Input_B),
          .B(ALU_Out_CPU),
          .C(Mem_Data_OUT),
          .Out(Input_Reg_B)
        );

  Mem mem(
        .clk(clk),
        .addr(PC), // Dirección fija para esta prueba
        .Data_IN(ALU_Out_CPU),
        .Data_OUT(Mem_Data_OUT),
        .we(0)
      );

  CONTROL control(
            .IR(IR),
            .MUX_A_sel(MUX_A_sel),
            .MUX_B_sel(MUX_B_sel),
            .wr_REG_A(we_REG_A),
            .wr_REG_B(we_REG_B),
            .wr_ALU_out(wr_ALU_Out),
            .ALU_Op(ALU_Op),
            .clk(clk),
            .reset(reset),
            .wr_IR(wr_IR),
            .Inc_PC(Inc_PC)
          );

endmodule
