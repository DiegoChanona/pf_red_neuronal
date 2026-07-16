// Requantizacion de la activacion oculta (capa 1 -> capa 2).
// La spec fija el orden:  ReLU  ->  >>> SHIFT1  ->  clamp(255)  ->  uint8
//
//   1) ReLU: si el acumulador es negativo, salida 0; si no, pasa el valor.
//   2) Shift aritmetico a la derecha SHIFT1 posiciones. Despues del ReLU el valor ya es
//      >=0, asi que aritmetico y logico dan lo mismo; uso '>>>' sobre signed solo para
//      dejarlo explicito.
//   3) Clamp a CLAMP_MAX (255) comparando en el ancho completo ANTES de truncar a 8
//      bits. Si truncas primero y comparas despues, saturas mal (wraparound).
module requant_unit #(
  parameter int SHIFT1    = 5,
  parameter int CLAMP_MAX = 255   // debe caber en 8 bits (ancho fijo de 'act')
)(
  input  logic signed [31:0] acc,
  output logic        [7:0]  act
);

  logic signed [31:0] relu_val;
  logic signed [31:0] shifted_val;

  assign relu_val    = acc[31] ? 32'sd0 : acc;   // ReLU
  assign shifted_val = relu_val >>> SHIFT1;      // shift aritmetico (relu_val ya es >=0)

  assign act = (shifted_val > CLAMP_MAX) ? CLAMP_MAX[7:0] : shifted_val[7:0]; // clamp antes de truncar

endmodule
