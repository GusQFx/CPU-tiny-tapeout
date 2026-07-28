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

module CONTROL (
    input logic clk,
    input logic reset,
    input  logic [7:0] IR,
    output logic [0:0] wr_IR,
    output logic [1:0] MUX_A_sel,
    output logic [1:0] MUX_B_sel,
    output logic [0:0] wr_REG_A,
    output logic [0:0] wr_REG_B,
    output logic [1:0] wr_ALU_out,
    output logic [0:0] ALU_Op,
    output logic [0:0] Inc_PC

  );
  logic [1:0] Estado  = 2'b00; // 0 cargar IR, 1 ejecutar instrucción, 2 PC = PC + 1

  always @(*)
  begin
    if (reset)
    begin
      Estado <= 2'b00;
      MUX_A_sel  <= 2'b00;
      MUX_B_sel  <= 2'b00;
      wr_REG_A   <= 1'b0;
      wr_REG_B   <= 1'b0;
      wr_ALU_out <= 2'b00;
      ALU_Op     <= 1'b0;
      Inc_PC     <= 1'b0;
    end
  end

  always @(posedge clk)
  begin
    if (Estado == 0)
    begin
      wr_IR <= 1'b1;
      Estado <= 2'b01;

      MUX_A_sel  <= 2'b00;
      MUX_B_sel  <= 2'b00;
      wr_REG_A   <= 1'b0;
      wr_REG_B   <= 1'b0;
      wr_ALU_out <= 2'b00;
      ALU_Op     <= 1'b0;
      Inc_PC     <= 1'b0;
    end
  end

  always @(posedge clk)
  begin
    if (Estado == 1)
    begin
      wr_IR <= 1'b0;

      if (IR == 8'h00)
      begin // NOP
        // No hace nada, solo avanza al siguiente estado.
      end

      if (IR == 8'h01)
      begin // SUMA
        ALU_Op <= 1'b1;
        wr_ALU_out <= 2'b01;
      end

      if (IR == 8'h02)
      begin // RESTA
        ALU_Op     <= 1'b0;
        wr_REG_A   <= 1'b1;
        wr_ALU_out <= 2'b01;
      end

      if (IR == 8'h03)
      begin // LOAD External -> A
        MUX_A_sel  <= 2'b00;
        wr_REG_A   <= 1'b1;
      end

      if (IR == 8'h04)
      begin // LOAD External -> B
        MUX_B_sel  <= 2'b00;
        wr_REG_B   <= 1'b1;
      end

      if (IR == 8'h05)
      begin // STORE ALU -> REG A
        MUX_A_sel <= 2'b01;
        wr_REG_A  <= 1'b1;
      end

      if (IR == 8'h06)
      begin // STORE ALU -> REG B
        MUX_B_sel <= 2'b01;
        wr_REG_B  <= 1'b1;
      end

      Estado <= 2'b10;
    end
  end

  always @(posedge clk)
  begin
    if (Estado == 2'b10)
    begin
      Inc_PC <= 1'b1;
      Estado <= 2'b00;
    end
  end

endmodule

module Mem (
    input  logic [0:0] clk,
    input  logic [7:0] addr,
    input  logic [7:0] Data_IN,
    output logic [7:0] Data_OUT,
    input  logic [0:0] we
  );

  // Memoria: 256 posiciones de 8 bits
  logic [7:0] mem [0:255];

  initial
  begin

    // Icarus prefiere inicializar el array dentro del bloque
    for (int i = 0; i < 256; i++)
    begin
      mem[i] = 8'h00;
    end

    mem[0] = 8'h00;
    mem[1] = 8'h03;
    mem[2] = 8'h04;
    mem[3] = 8'h01;
    mem[4] = 8'h06;
    mem[5] = 8'h01;
    mem[6] = 8'h06;
    mem[7] = 8'h01;
    mem[8] = 8'h06;
    mem[9] = 8'h00;
  end


  always_ff @(posedge clk)
  begin
    if (we)
      mem[addr] <= Data_IN;   // escritura
    Data_OUT <= mem[addr];      // lectura
  end

endmodule

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

module REGPC (
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
            Data_OUT = Data_IN + 1;
    end
endmodule