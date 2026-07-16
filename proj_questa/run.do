# run.do  -  compila y simula el testbench principal de la red neuronal
#
# Uso (desde la carpeta proj_questa):
#   vsim -c -do run.do          (modo batch: corre y sale)
#   do run.do                   (desde una consola de Questa ya abierta)
#
# El diseno asume dos rutas distintas para sus datos, asi que primero las dejamos
# al alcance del cwd (proj_questa):
#   - las ROMs leen  tb/weights.hex  y  tb/biases.hex
#   - el testbench lee  test_images.hex, test_labels.txt, test_golden.txt  en la raiz

# --- 1. Datos ---
file mkdir tb
file copy -force ../src/tb/weights.hex     tb/weights.hex
file copy -force ../src/tb/biases.hex      tb/biases.hex
file copy -force ../src/tb/test_images.hex test_images.hex
file copy -force ../src/tb/test_labels.txt test_labels.txt
file copy -force ../src/tb/test_golden.txt test_golden.txt

# --- 2. Compilacion ---
# work limpia para no arrastrar compilaciones viejas
if {[file exists work]} { vdel -all }
vlib work

# Todos los modulos del diseno + solo el tb principal (no los tb unitarios)
vlog -sv ../src/*.sv ../src/tb/neural_network_digits_tb.sv

# --- 3. Simulacion ---
vsim neural_network_digits_tb
run -all

# Solo cierra Questa si se lanzo en modo batch (-c); en modo interactivo se queda
# abierto para inspeccionar senales u ondas.
if {[batch_mode]} { quit -f }
