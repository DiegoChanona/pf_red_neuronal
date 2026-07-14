// Bloque de requantizacion de la activacion oculta (capa 1 -> capa 2).
//
// Pipeline no negociable de la especificacion:  ReLU  ->  >>> SHIFT1  ->  clamp(255)  ->  uint8
//
//   1) ReLU: si el acumulador es negativo (bit de signo=1) la salida es 0,
//      si no, pasa el valor completo.
//   2) Shift aritmetico a la derecha por SHIFT1 posiciones. Tras el ReLU el
//      valor ya es >=0, asi que aritmetico y logico coinciden en la practica;
//      se usa '>>>' sobre un tipo signed para que quede explicito y no
//      dependa de que la herramienta infiera el shift correcto.
//   3) Clamp a CLAMP_MAX (255): la comparacion y la saturacion se hacen en
//      el ancho completo ANTES de truncar a 8 bits. Truncar primero y
//      comparar despues produce wraparound en vez de saturacion (bug clasico).
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
