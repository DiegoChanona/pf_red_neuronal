// Argmax "al vuelo": comparador signed con estado. Recibe un score por ciclo (uno por
// neurona de la capa de salida) y se queda con el indice del maximo.
//
// Detalles que fija la spec:
//   - best_score arranca en 32'h8000_0000 (el minimo int32).
//   - la comparacion es SIGNED.
//   - en empate gana el primer indice -> comparacion estricta '>' (un score igual al
//     mejor actual no lo reemplaza).
//
// 'clear' reinicia best_score/best_index sin usar el reset global; la FSM lo activa al
// arrancar cada barrido (una vez por imagen, antes de las 10 neuronas de salida).
// 'valid' marca que 'score' sirve para comparar en este ciclo.
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
      best_score <= 32'sh8000_0000; //se inicia con el valor minimo para que cualquier score sea mayor
      best_index <= '0;
    end else if (clear) begin
      best_score <= 32'sh8000_0000; 
      best_index <= '0;
    end else if (valid && (score > best_score)) begin //se compara el score actual con el mejor score guardado
      best_score <= score;
      best_index <= index;
    end
  end

endmodule
