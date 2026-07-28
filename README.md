# CPU-tiny-tapeout
Este es el repositorio del proyecto para el Tiny Tape Out de septiembre 2026.

## Estructura

```
src/     -> módulos de la CPU (ALU, CONTROL, Mem, MUX, MUX_3, REG, REGPC, CPU)
           + tt_um_TEMPLATE.sv: esqueleto del wrapper que exige Tiny Tapeout
tb/      -> testbench propio para simular localmente con iverilog + gtkwave
docs/    -> info.md (ficha del proyecto para el datasheet) + diagramas
legacy/  -> versiones monolíticas viejas, ya no se compilan (solo referencia)
build/   -> artefactos de simulación generados (ignorado por git)
info.yaml -> metadata que exige Tiny Tapeout (título, top_module, pinout, etc.)
LICENSE  -> Apache-2.0, requerida por Tiny Tapeout para el envío
```

## Pendiente antes de poder enviar a Tiny Tapeout

Estas son decisiones de diseño que quedaron para completar (ver los
comentarios `TODO` dentro de cada archivo para el detalle de cada punto):

1. **`src/tt_um_TEMPLATE.sv`**: definir cómo se adapta la interfaz de 8+8+8
   pines de Tiny Tapeout (`ui_in`/`uo_out`/`uio_*`) a los 24 bits de entrada
   que hoy pide `src/CPU.sv` (Input_A + Input_B + input_IR a la vez), e
   invertir la polaridad del reset (`rst_n` es activo en bajo, `reset` de
   `CONTROL.sv` es activo en alto). Una vez resuelto, renombrar el archivo
   y el módulo con un nombre único, ej. `tt_um_gusqfx_cpu_basica`.
2. **`info.yaml`**: completar `title`, `author`, `description`, `clock_hz`,
   `top_module` (debe coincidir con el nombre del wrapper de arriba),
   `source_files` (agregar el archivo del wrapper) y `tiles` (se ajusta
   después de ver el reporte de área de la síntesis).
3. **`docs/info.md`**: completar las secciones "How it works" / "How to
   test" con la explicación real del proyecto.
4. **Bug conocido, no corregido**: `src/CONTROL.sv` usa `always @(*)` para
   las transiciones de estado en vez de `always @(posedge clk)`, lo que
   genera un lazo combinacional en vez de una FSM sincronizada. Muy
   probablemente bloquee la síntesis (Yosys lo marcaría como "combinational
   loop"). Queda pendiente de tu parte, junto con lo demás.
5. **Flujo de CI oficial** (`.github/workflows`, testbench en Python con
   cocotb dentro de `test/`): todavía no está copiado desde el template
   oficial de Tiny Tapeout — hace falta traerlo del shuttle vigente cuando
   se abra la convocatoria de septiembre 2026, porque cambia de shuttle en
   shuttle.
