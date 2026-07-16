// ROM de biases: 26 x int32, cargada desde biases.hex.
//   addr 0..15  -> biases de las 16 neuronas de la capa 1
//   addr 16..25 -> biases de las 10 neuronas de la capa 2
// Un solo puerto: en cada pasada 0 se lee el bias de la neurona en curso, que entra al
// arbol de CSAs como fila del acumulador.
module biases_rom #(
  parameter int NUM_BIASES = 26,
  parameter int ADDR_WIDTH = 5
)(
  input  logic [ADDR_WIDTH-1:0] addr,
  output logic signed [31:0]    dout
);

  logic [31:0] mem [0:NUM_BIASES-1];

  initial $readmemh("tb/biases.hex", mem);

  assign dout = $signed(mem[addr]);

endmodule
