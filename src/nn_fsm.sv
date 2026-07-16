/* Maquina de estados para el control de la red neuronal.
   Estados: IDLE, LOAD_IMG, LAYER1, LAYER2, DONE
     IDLE:     espera la señal de start
     LOAD_IMG: carga la imagen en la memoria
     LAYER1:   primera capa, 16 neuronas
     LAYER2:   segunda capa, 10 neuronas
     DONE:     termino de procesar

   Todo el timing cuelga de dos contadores anidados: pass_idx (que grupo de 8 datos
   dentro de la neurona) y neuron_idx (que neurona de la capa). Como dot_product_fma8 es
   combinacional, cada ciclo en LAYER1/LAYER2 resuelve una pasada completa de 8 MACs:

     LAYER1: 16 neuronas x 8 pasadas (64 entradas) = 128 ciclos
     LAYER2: 10 neuronas x 2 pasadas (16 entradas) =  20 ciclos
     + LOAD_IMG + DONE                             = 150 ciclos por inferencia

   No hacen falta burbujas entre neuronas: en la pasada 0 el acumulador se carga con el
   bias en lugar del valor realimentado, asi que el acc viejo simplemente se descarta.
*/
module nn_fsm
(
input logic clk,
input logic rst,
input logic start,

// del datapath
input  logic [3:0] best_index,   // indice ganador del argmax

// hacia el datapath
output logic       img_load,     // registra la imagen de entrada
output logic       layer_sel,    // 0 = capa 1, 1 = capa 2
output logic [3:0] neuron_idx,   // neurona en curso (0..15 en L1, 0..9 en L2)
output logic [2:0] pass_idx,     // pasada en curso (0..7 en L1, 0..1 en L2)
output logic       acc_first,    // pasada 0: acc_in = bias, no el acumulador
output logic       acc_en,       // registra acc_next
output logic       hidden_we,    // escribe la activacion requantizada
output logic [3:0] hidden_waddr,
output logic       argmax_clr,   // best_score <- 32'h8000_0000
output logic       argmax_en,    // compara el score de esta neurona

output logic done,
output logic [4:0] digit
);

// Topologia de la red: 64 -> 16 (ReLU) -> 10
localparam int NEURONS_L1 = 16;
localparam int NEURONS_L2 = 10;
localparam int PASSES_L1  = 8;   // 64 entradas / 8 carriles
localparam int PASSES_L2  = 2;   // 16 entradas / 8 carriles

// Definicion de estados

typedef enum logic [2:0] {
    IDLE,
    LOAD_IMG,
    LAYER1,
    LAYER2,
    DONE
} state_t;

state_t state, next_state;

logic last_pass, last_neuron;

// Lógica de transición de estados
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// La capa en curso se deduce del estado, no necesita registro propio
assign layer_sel = (state == LAYER2);

// Topes de los contadores segun la capa
assign last_pass   = layer_sel ? (pass_idx   == PASSES_L2  - 1)
                               : (pass_idx   == PASSES_L1  - 1);
assign last_neuron = layer_sel ? (neuron_idx == NEURONS_L2 - 1)
                               : (neuron_idx == NEURONS_L1 - 1);

// Contadores anidados: pass_idx gira dentro de neuron_idx
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        neuron_idx <= '0;
        pass_idx   <= '0;
    end else begin
        case (state)
            IDLE, LOAD_IMG, DONE: begin
                neuron_idx <= '0;
                pass_idx   <= '0;
            end
            LAYER1, LAYER2: begin
                if (last_pass) begin
                    pass_idx <= '0;
                    // al agotar la capa los contadores vuelven a 0 para la siguiente
                    neuron_idx <= last_neuron ? 4'd0 : (neuron_idx + 4'd1);
                end else begin
                    pass_idx <= pass_idx + 3'd1;
                end
            end
            default: begin
                neuron_idx <= '0;
                pass_idx   <= '0;
            end
        endcase
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
            // se permanece en la capa hasta agotar las 16 neuronas x 8 pasadas
            next_state = (last_pass && last_neuron) ? LAYER2 : LAYER1;
        end
        LAYER2: begin
            next_state = (last_pass && last_neuron) ? DONE : LAYER2;
        end
        DONE: begin
            next_state = IDLE;
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end

// Señales de control hacia el datapath
assign img_load     = (state == LOAD_IMG);
assign acc_en       = (state == LAYER1) || (state == LAYER2);
assign acc_first    = (pass_idx == '0);

// En la ultima pasada de una neurona de la capa 1, acc_next ya es el acumulador
// completo: se requantiza y se guarda como activacion oculta.
assign hidden_we    = (state == LAYER1) && last_pass;
assign hidden_waddr = neuron_idx;

// El argmax se limpia una vez por imagen y compara el score crudo de cada neurona
// de salida en su ultima pasada.
assign argmax_clr   = (state == LOAD_IMG);
assign argmax_en    = (state == LAYER2) && last_pass;

assign done  = (state == DONE);
assign digit = {1'b0, best_index};

endmodule
