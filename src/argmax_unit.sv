// Argmax "al vuelo": comparador signed con estado, que va recibiendo un
// score a la vez (uno por neurona de la capa de salida) y se queda con el
// indice del maximo.
//
// Contrato de la especificacion:
//   - best_score se inicializa en 32'h8000_0000 (el minimo int32 representable).
//   - la comparacion es SIGNED.
//   - en caso de empate gana el PRIMER indice recorrido -> se logra con
//     comparacion estricta '>' (un score igual al mejor actual NO lo reemplaza).
//
// 'clear' reinicia best_score/best_index sin pasar por reset global; lo usa
// la FSM al arrancar cada pasada de argmax (una vez por imagen, antes de
// recorrer las 10 neuronas de la capa de salida). 'valid' marca que 'score'
// es un dato valido para comparar en este ciclo.
module argmax_unit #(
  parameter int NUM_CLASSES = 10,
  parameter int INDEX_WIDTH = 4
)(
  input  logic                   clk,
  input  logic                   rst,
  input  logic                   clear,
  input  logic                   valid,
  input  logic signed [31:0]     score,
  input  logic [INDEX_WIDTH-1:0] index,
  output logic signed [31:0]     best_score,
  output logic [INDEX_WIDTH-1:0] best_index
);

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      best_score <= 32'sh8000_0000;
      best_index <= '0;
    end else if (clear) begin
      best_score <= 32'sh8000_0000;
      best_index <= '0;
    end else if (valid && (score > best_score)) begin
      best_score <= score;
      best_index <= index;
    end
  end

endmodule
