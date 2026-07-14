/*maquina de estados finitos para el control de la red neuronal
 Los estados manejados son: IDLE, LOAD_IMG, LAYER1, LAYER2, DONE
IDLE: espera la señal de estart 
LOAD_IMG: carga la imagen en la memoria
LAYER1: realiza la primera capa de la red neuronal (16 neuronas)
LAYER2: realiza la segunda capa de la red neuronal (10 neuronas)
DONE: indica que la red neuronal ha terminado de procesar

*/
module nn_fsm
(
input logic clk,
input logic rst,
input logic start,
output logic done,
output logic [4:0] digit
);

// Definicion de estados

typedef enum logic [2:0] {
    IDLE,
    LOAD_IMG,
    LAYER1,
    LAYER2,
    DONE
} state_t;

state_t state, next_state;

// Lógica de transición de estados
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Lógica de siguiente estado
always_comb begin
    case (state)
        IDLE: begin
            if (start) begin
                next_state = LOAD_IMG;
            end else begin
                next_state = IDLE;
            end
        end
        LOAD_IMG: begin
            next_state = LAYER1;
        end
        LAYER1: begin
            next_state = LAYER2;
        end
        LAYER2: begin
            next_state = DONE;
        end
        DONE: begin
            next_state = IDLE;
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule