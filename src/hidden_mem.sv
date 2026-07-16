// Memoria de activaciones de la capa oculta: 16 x uint8.
//
// La escribe la capa 1 (una activacion requantizada por neurona, al cerrar su ultima
// pasada) y la lee la capa 2 en grupos de 8 (dos pasadas cubren las 16 entradas).
// Escritura sincrona, lectura combinacional por 8 puertos, uno por carril del dot product.
module hidden_mem #(
  parameter int DEPTH      = 16,
  parameter int ADDR_WIDTH = 4,
  parameter int NUM_PORTS  = 8
)(
  input  logic                  clk,
  input  logic                  we,
  input  logic [ADDR_WIDTH-1:0] waddr,
  input  logic [7:0]            wdata,
  input  logic [ADDR_WIDTH-1:0] raddr [NUM_PORTS],
  output logic [7:0]            rdata [NUM_PORTS]
);

  logic [7:0] mem [0:DEPTH-1];

  always_ff @(posedge clk) begin
    if (we) mem[waddr] <= wdata;
  end

  always_comb begin
    for (int p = 0; p < NUM_PORTS; p++)
      rdata[p] = mem[raddr[p]];
  end

endmodule
