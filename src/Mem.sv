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

