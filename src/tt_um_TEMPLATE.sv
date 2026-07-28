/*
 * ============================================================================
 * PLANTILLA DEL MODULO TOP QUE EXIGE TINY TAPEOUT
 * ============================================================================
 * Este archivo es un ESQUELETO. No está conectado a tu CPU todavía, y no
 * debe estarlo hasta que TÚ decidas cómo resolver los puntos marcados TODO
 * más abajo — son decisiones de diseño, no de "formato", así que no las
 * tomamos por ti.
 *
 * Por qué existe este archivo:
 * Tiny Tapeout exige que el módulo top del chip tenga EXACTAMENTE esta
 * firma de puertos (nombres y anchos fijos, no se pueden cambiar):
 *
 *   ui_in    [7:0]  -> 8 entradas dedicadas (solo lectura)
 *   uo_out   [7:0]  -> 8 salidas dedicadas (solo escritura)
 *   uio_in   [7:0]  -> 8 pines bidireccionales, lado LECTURA
 *   uio_out  [7:0]  -> 8 pines bidireccionales, lado ESCRITURA
 *   uio_oe   [7:0]  -> por cada bit: 1 = ese pin actúa como salida,
 *                                     0 = ese pin actúa como entrada
 *   ena             -> siempre en 1 mientras el chip está encendido
 *                       (según el template oficial, en la práctica se puede
 *                       ignorar la mayoría de las veces)
 *   clk             -> reloj
 *   rst_n           -> reset, ACTIVO EN BAJO (0 = reset)
 *
 * Tu src/CPU.sv NO tiene esta interfaz (tiene clk, reset, Input_A, Input_B,
 * input_IR, ALU_Out_CPU) así que hace falta un módulo "adaptador" (wrapper)
 * entre la interfaz de Tiny Tapeout y tu CPU. Eso es lo que va en este
 * archivo — cuando lo completes.
 *
 * QUÉ FALTA DECIDIR (TODO), y por qué no está resuelto aquí:
 *
 *  1. Polaridad del reset:
 *     rst_n de Tiny Tapeout es activo en BAJO. Tu CONTROL.sv espera "reset"
 *     activo en ALTO. Alguien tiene que invertir la señal en algún punto
 *     (ej. .reset(!rst_n) al instanciar CPU), pero confírmalo tú mismo,
 *     no lo hicimos aquí para no tocar CONTROL.sv ni asumir por ti.
 *
 *  2. Cómo entran A, B e IR (24 bits) por solo 16 pines (ui_in + uio_in):
 *     Tu CPU pide Input_A[7:0], Input_B[7:0] e input_IR[7:0] disponibles
 *     "a la vez". Tiny Tapeout solo te da 8 ui_in + 8 uio_in = 16 entradas
 *     como máximo, y los uio ni siquiera son entrada pura (son
 *     bidireccionales, compartidos con la salida). Opciones típicas:
 *       a) Cargar A, B e IR en varios ciclos de reloj con un protocolo
 *          propio (ej. 2 bits de "selector" + 8 bits de dato en ui_in,
 *          usando algunos uio como líneas de control).
 *       b) Usar los uio_* como bus de datos compartido y ui_in como
 *          líneas de control/selección.
 *     Cuál conviene depende de qué tan rápido necesitas cargar datos y
 *     cuántos pines quieres "gastar" en control — por eso te toca a ti.
 *
 *  3. Qué exponer en uo_out:
 *     Lo más directo es ALU_Out_CPU (la salida que ya tiene tu CPU), pero
 *     confírmalo según qué quieras poder observar/verificar del chip real.
 *
 *  4. input_IR sin usar dentro de CPU.sv:
 *     Ojo — src/CPU.sv declara el puerto input_IR pero no lo conecta a
 *     nada internamente (el IR real se carga desde Mem_Data_OUT). Antes
 *     de cablear este wrapper, probablemente quieras revisar/decidir si
 *     ese puerto se seguirá usando o se elimina (eso sí sería tocar
 *     CPU.sv, así que queda pendiente para cuando tú lo abordes).
 *
 * Una vez que tomes estas decisiones:
 *   - Completa la instancia de CPU más abajo (está de ejemplo, comentada).
 *   - Cambia el nombre de este archivo y del módulo a algo único con tu
 *     usuario de GitHub, ej: tt_um_gusqfx_cpu_basica.sv / module
 *     tt_um_gusqfx_cpu_basica.
 *   - Actualiza info.yaml: top_module y source_files.
 * ============================================================================
 */

// `default_nettype none` es una convención del template oficial de Tiny
// Tapeout: desactiva los "wires implícitos" de Verilog, así que si escribes
// mal el nombre de una señal, te va a tirar error de compilación en vez de
// crear silenciosamente un cable nuevo sin conectar (un error muy común y
// difícil de detectar a simple vista).
`default_nettype none

module tt_um_TEMPLATE (
    input  wire [7:0] ui_in,    // Entradas dedicadas
    output wire [7:0] uo_out,   // Salidas dedicadas
    input  wire [7:0] uio_in,   // Bidireccional: lectura
    output wire [7:0] uio_out,  // Bidireccional: escritura
    output wire [7:0] uio_oe,   // Bidireccional: dirección (1=salida, 0=entrada)
    input  wire        ena,     // En alto mientras el chip está encendido
    input  wire        clk,     // Reloj
    input  wire        rst_n    // Reset activo en BAJO
);

  // --------------------------------------------------------------------
  // Mientras no esté conectado el CPU real, todas las salidas quedan en
  // un valor fijo y conocido (0). Esto es obligatorio: Tiny Tapeout no
  // permite salidas "sin manejar" (Yosys lo marcaría como warning/error
  // de síntesis). Cuando conectes tu CPU, estas líneas se reemplazan.
  // --------------------------------------------------------------------
  assign uo_out  = 8'h00;
  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;   // 0 = todos los uio como entrada, por ahora

  // Evita warnings de "señal sin usar" mientras ui_in/uio_in/ena no están
  // conectadas a nada todavía (es normal verlas "grises" en el simulador
  // hasta que completes el wrapper).
  wire _unused = &{ena, ui_in, uio_in, 1'b0};

  // --------------------------------------------------------------------
  // EJEMPLO (comentado, no activo) de cómo se vería instanciar tu CPU una
  // vez que resuelvas los puntos 1, 2 y 3 de arriba. Bórralo o edítalo,
  // esto es solo referencia.
  // --------------------------------------------------------------------
  // wire [7:0] alu_out;
  //
  // CPU cpu_inst (
  //     .clk(clk),
  //     .reset(!rst_n),        // ejemplo de inversion de polaridad (punto 1)
  //     .Input_A(/* TODO: punto 2 */),
  //     .Input_B(/* TODO: punto 2 */),
  //     .input_IR(/* TODO: punto 2 y 4 */),
  //     .ALU_Out_CPU(alu_out)
  // );
  //
  // assign uo_out = alu_out;   // ejemplo del punto 3

endmodule
