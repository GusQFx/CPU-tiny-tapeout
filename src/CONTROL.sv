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

  always @(*)
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

  always @(*)
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

  always @(*)
  begin
    if (Estado == 2'b10)
    begin
      Inc_PC <= 1'b1;
      Estado <= 2'b00;
    end
  end

endmodule

