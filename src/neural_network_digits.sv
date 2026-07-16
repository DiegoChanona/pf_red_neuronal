/*
Top del clasificador de digitos: MLP 64 -> 16 (ReLU) -> 10 -> argmax, todo en enteros.

La FSM (nn_fsm) recorre neuronas y pasadas; entre capa 1 y capa 2 lo unico que cambia
son las fuentes de los muxes:

              capa 1 (layer_sel=0)          capa 2 (layer_sel=1)
  data[k]     pixel uint4 zero-extendido    activacion oculta uint8
  weight[k]   ROM addr 64*n + 8*p + k       ROM addr 1024 + 16*n + 8*p + k
  acc_in      bias[n]        (pasada 0)     bias[16+n]     (pasada 0)
              acc_reg        (resto)        acc_reg        (resto)
  salida      ReLU >>5 clamp255 -> hidden   score int32 crudo -> argmax

La capa de salida va sin ReLU ni shift: los scores crudos entran directo al argmax, que
es lo que pide la spec para dar bit-exacto contra la referencia.
*/
module neural_network_digits
#(
parameter IMAGE_PIXEL_WIDTH = 4,
parameter IMAGE_HORIZONTAL_SIZE = 8,
parameter IMAGE_VERTICAL_SIZE = 8,
parameter DIGIT_WIDTH = 5)(
input logic clk ,
input logic rst ,
input logic start ,
input logic [ IMAGE_PIXEL_WIDTH -1:0] image [ IMAGE_HORIZONTAL_SIZE -1:0]
                                            [ IMAGE_VERTICAL_SIZE -1:0] , // 8x8 Digit
output logic done ,
output logic [ DIGIT_WIDTH -1:0] digit
);

  localparam int N          = 8;     // carriles del producto punto
  localparam int NUM_PIXELS = IMAGE_HORIZONTAL_SIZE * IMAGE_VERTICAL_SIZE;  // 64
  localparam int L2_BASE    = 1024;  // primer peso de la capa 2 en la ROM
  localparam int L2_BIAS    = 16;    // primer bias de la capa 2 en la ROM

  // --- Control ---
  logic       img_load, layer_sel, acc_first, acc_en;
  logic       hidden_we, argmax_clr, argmax_en;
  logic [3:0] neuron_idx, hidden_waddr, best_index;
  logic [2:0] pass_idx;

  nn_fsm u_fsm (
    .clk         (clk),
    .rst         (rst),
    .start       (start),
    .best_index  (best_index),
    .img_load    (img_load),
    .layer_sel   (layer_sel),
    .neuron_idx  (neuron_idx),
    .pass_idx    (pass_idx),
    .acc_first   (acc_first),
    .acc_en      (acc_en),
    .hidden_we   (hidden_we),
    .hidden_waddr(hidden_waddr),
    .argmax_clr  (argmax_clr),
    .argmax_en   (argmax_en),
    .done        (done),
    .digit       (digit)
  );

  // --- Registro de la imagen ---
  // El pixel lineal i (el mismo que indexa los pesos, addr = 64*n + i) vive en
  // image[i/8][i%8]. Si inviertes fila/columna la simulacion corre igual, pero el orden
  // deja de coincidir con el del entrenamiento y el accuracy se cae sin avisar.
  logic [IMAGE_PIXEL_WIDTH-1:0] img_reg [NUM_PIXELS];

  always_ff @(posedge clk) begin
    if (img_load) begin
      for (int i = 0; i < NUM_PIXELS; i++)
        img_reg[i] <= image[i / IMAGE_VERTICAL_SIZE][i % IMAGE_VERTICAL_SIZE];
    end
  end

  // --- Indice lineal de las 8 entradas de la pasada en curso ---
  logic [5:0] in_idx [N];   // 0..63 en capa 1, 0..15 en capa 2

  always_comb begin
    for (int k = 0; k < N; k++)
      in_idx[k] = 6'(pass_idx) * 6'(N) + 6'(k);
  end

  // --- Memorias ---
  logic [10:0]       w_addr [N];
  logic signed [7:0] weight [N];
  logic [4:0]        bias_addr;
  logic signed [31:0] bias;
  logic [3:0]        hidden_raddr [N];
  logic [7:0]        hidden_rdata [N];
  logic [7:0]        act;

  //calculamos la dirección de los pesos y de la activación oculta
  always_comb begin
    for (int k = 0; k < N; k++) begin
      // capa 1: 64*n + i        capa 2: 1024 + 16*n + i
      w_addr[k] = layer_sel ? 11'(L2_BASE + 16 * int'(neuron_idx) + int'(in_idx[k]))
                            : 11'(64 * int'(neuron_idx) + int'(in_idx[k]));
      hidden_raddr[k] = in_idx[k][3:0];
    end
  end
  //calculamos la dirección del bias 
  assign bias_addr = layer_sel ? 5'(L2_BIAS + int'(neuron_idx)) : 5'(neuron_idx);

//leemos los pesos y bias de la ROM 
  weights_rom u_weights (.addr(w_addr), .dout(weight));
  biases_rom  u_biases  (.addr(bias_addr), .dout(bias));

//Memoria de la capa oculta, donde se escriben las activaciones de la capa 1 y se leen en la capa 2
  hidden_mem u_hidden (
    .clk   (clk),
    .we    (hidden_we),
    .waddr (hidden_waddr),
    .wdata (act),
    .raddr (hidden_raddr),
    .rdata (hidden_rdata)
  );

  // --- Datapath: mux de fuentes + producto punto fusionado ---
  logic [7:0]         data [N];
  logic signed [31:0] acc_in, acc_next, acc_reg;

  always_comb begin
    for (int k = 0; k < N; k++)
      data[k] = layer_sel ? hidden_rdata[k]                        // activacion uint8
                          : {4'b0, img_reg[in_idx[k]]};            // pixel uint4 -> uint8
  end

  // En la pasada 0 el acumulador se siembra con el bias; en las demas se realimenta.
  assign acc_in = acc_first ? bias : acc_reg;

  dot_product_fma8 #(.N(N)) u_dot (
    .data   (data),
    .weight (weight),
    .acc_in (acc_in),
    .acc_out(acc_next)
  );

  always_ff @(posedge clk or posedge rst) begin
    if (rst)          acc_reg <= '0;
    else if (acc_en)  acc_reg <= acc_next;
  end

  // --- Capa 1: requantizacion de la activacion oculta ---
  // Requantizo acc_next (el acumulador ya completo de esta ultima pasada), no acc_reg,
  // que todavia trae el valor de la pasada anterior.
  // siempre calcula pero solo guarda el valor cuando hidden_we=1 (una vez por neurona, al final de la pasada 1).
  requant_unit #(.SHIFT1(5), .CLAMP_MAX(255)) u_requant (
    .acc(acc_next),
    .act(act)
  );

  // --- Capa 2: argmax sobre los scores crudos ---
  logic signed [31:0] best_score_unused;

  argmax_unit #(.NUM_CLASSES(10), .INDEX_WIDTH(4)) u_argmax (
    .clk       (clk),
    .rst       (rst),
    .clear     (argmax_clr),
    .valid     (argmax_en),
    .score     (acc_next),
    .index     (neuron_idx),
    .best_score(best_score_unused),
    .best_index(best_index)
  );

endmodule
