# Restricciones de temporizacion (SDC) para neural_network_digits.
#
# Sin este archivo, TimeQuest analiza contra un periodo por defecto de 1 ns (1 GHz)
# y todo reporte de setup sale con slack enorme negativo, aunque el diseno corra bien.
#
# El diseno cierra a ~54.88 MHz (camino critico ~18.2 ns, dominado por el arbol de CSAs
# + el CPA del dot_product_fma8). Se restringe a 50 MHz (20 ns), que cierra con holgura
# positiva. Ajusta el periodo a tu objetivo: bajarlo hacia 18.2 ns lo lleva al limite.

# --- Reloj principal ---
create_clock -name clk -period 20.000 [get_ports clk]

# Incertidumbre de reloj (jitter/skew del modelo del dispositivo)
derive_clock_uncertainty

# --- Entradas/salidas ---
# En este diseno la imagen se asume estable antes de 'start' y los puertos de control
# (start, done, digit) se muestrean de forma sincrona en el testbench; no hay una
# especificacion de timing externo. Se relajan las rutas de I/O para que no ensucien
# el reporte con caminos de puerto no restringidos que no forman parte del objetivo.
set_false_path -from [get_ports rst]
set_false_path -from [get_ports start]
set_false_path -from [get_ports {image[*][*]}]
set_false_path -to   [get_ports done]
set_false_path -to   [get_ports {digit[*]}]
