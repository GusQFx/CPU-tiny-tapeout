# ================================
# Herramientas
# ================================
IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

# ================================
# Carpetas
# ================================
SRC_DIR   = src
TB_DIR    = tb
BUILD_DIR = build

# ================================
# Archivos
# ================================

SRC = $(wildcard $(SRC_DIR)/*.sv) $(wildcard $(TB_DIR)/*.sv)
TOP = Testbench          # cambia esto si tu módulo top tiene otro nombre
OUT = $(BUILD_DIR)/sim.out
VCD = $(BUILD_DIR)/dump.vcd

# ================================
# Flags
# ================================
FLAGS = -g2012 -Wall

# ================================
# Targets
# ================================

.PHONY: all
all: wave

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compilar
.PHONY: compile
compile: $(BUILD_DIR)
	@echo "🔧 Compilando..."
	$(IVERILOG) $(FLAGS) -s $(TOP) -o $(OUT) $(SRC)

# Ejecutar
.PHONY: run
run: compile
	@echo "🚀 Ejecutando simulación..."
	$(VVP) $(OUT)

# Ver ondas
.PHONY: wave
wave: run
	@echo "📊 Abriendo GTKWave..."
	$(GTKWAVE) $(VCD) &

# Solo GTKWave (si ya corriste antes)
.PHONY: view
view:
	$(GTKWAVE) $(VCD) &

# Limpiar
.PHONY: clean
clean:
	@echo "🧹 Limpiando..."
	rm -rf $(BUILD_DIR)
