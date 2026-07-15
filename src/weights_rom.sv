// ROM de pesos: 1184 x int8, cargada desde weights.hex.
//
// Layout neuron-major de la especificacion (seccion 4.8):
//   peso capa 1: addr = 64*n + i     n en [0,15], i en [0,63]   -> 1024 pesos
//   peso capa 2: addr = 1024 + 16*n + i   n en [0,9], i en [0,15] -> 160 pesos
//
// Ocho puertos de lectura combinacionales, uno por carril del dot_product_fma8. Las 8
// direcciones de una pasada son contiguas, pero se exponen sueltas para no atar el
// modulo a esa suposicion.
module weights_rom #(
  parameter int NUM_WEIGHTS = 1184,
  parameter int ADDR_WIDTH  = 11,
  parameter int NUM_PORTS   = 8
)(
  input  logic [ADDR_WIDTH-1:0] addr [NUM_PORTS],
  output logic signed [7:0]     dout [NUM_PORTS]
);

  logic [7:0] mem [0:NUM_WEIGHTS-1];

  initial $readmemh("weights.hex", mem);

  always_comb begin
    for (int p = 0; p < NUM_PORTS; p++)
      dout[p] = $signed(mem[addr[p]]);
  end

endmodule
