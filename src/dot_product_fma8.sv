/*
Producto punto de 8 terminos con acumulador, todo en un solo arbol de Wallace.

    acc_out = sum(weight[i] * data[i], i=0..7) + acc_in

Los 8 multiplicadores no se resuelven por separado. Los productos parciales de Booth de
los ocho carriles, sus filas de correccion y el acumulador entran juntos al mismo arbol
de CSAs, con un unico Kogge-Stone al final. El acumulador entra como una fila mas, asi
que realimentarlo no cuesta un sumador extra: en la pasada 0 trae el bias y en las demas
el valor realimentado (el mux vive en la FSM).

Ojo con la signedness: el peso es int8 con signo pero el dato (pixel uint4 o activacion
uint8) es sin signo, y booth_radix4_pp usa un solo is_signed para ambos operandos. Por
eso el dato va zero-extendido a 9 bits ({1'b0, data}) y corremos Booth en modo signed.
Sin ese bit extra, una activacion de 200 se leeria como -56.
*/

module dot_product_fma8 #(
  parameter int N = 8   // carriles; el resto del diseno asume 8 (64 y 16 son multiplos)
)(
  input  logic        [7:0]  data   [N],  // pixel {4'b0, px} o activacion uint8
  input  logic signed [7:0]  weight [N],  // int8
  input  logic signed [31:0] acc_in,      // bias en la pasada 0, acc realimentado despues
  output logic signed [31:0] acc_out
);

  localparam int ACC_WIDTH  = 32;
  localparam int DATA_WIDTH = 9;                 // uint8 zero-extendido a signed de 9 bits
  localparam int W_WIDTH    = 8;                 // int8
  localparam int NUM_PP     = (W_WIDTH + 2) / 2; // 5 productos parciales por carril
  localparam int PP_WIDTH   = DATA_WIDTH + 2;    // 11 bits

  // Filas iniciales del arbol: los PPs de los 8 carriles, una fila de correccion por
  // carril, y el acumulador.
  localparam int PP_ROWS    = N * NUM_PP;        // 40
  localparam int CORR_ROWS  = N;                 // 8
  localparam int ACC_ROWS   = 1;                 // 1
  localparam int INIT_ROWS  = PP_ROWS + CORR_ROWS + ACC_ROWS;  // 49

  // Recurrencia real de la compresion 3:2, en vez de una formula cerrada de niveles:
  // cada nivel convierte n filas en 2*(n/3) + (n%3).
  function automatic int rows_after(int n, int lvl);
    for (int i = 0; i < lvl; i++) n = 2*(n/3) + (n%3);
    return n;
  endfunction

  // Cuantos niveles de compresion 3:2 hacen falta para llegar a 2 filas.
  // For de cota fija en vez de while: el elaborador de constantes de Quartus no acepta
  // while/break en una funcion constante. Cuando n<=2 las vueltas restantes no hacen
  // nada y lv se queda en su valor final.
  localparam int MAX_TREE_LEVELS = 64;
  function automatic int levels_to_two(int n);
    int lv;
    lv = 0;
    for (int i = 0; i < MAX_TREE_LEVELS; i++) begin
      if (n > 2) begin
        n  = 2*(n/3) + (n%3);
        lv = lv + 1;
      end
    end
    return lv;
  endfunction

  localparam int NUM_LEVELS = levels_to_two(INIT_ROWS);  // 49 -> ... -> 2 => 9

  // Si el arbol no cierra en exactamente 2 filas, el CPA final sumaria basura.
  initial begin
    if (rows_after(INIT_ROWS, NUM_LEVELS) != 2)
      $fatal(1, "dot_product_fma8: el arbol no converge a 2 filas (INIT_ROWS=%0d, NUM_LEVELS=%0d, quedan %0d)",
             INIT_ROWS, NUM_LEVELS, rows_after(INIT_ROWS, NUM_LEVELS));
  end

  // --- Los 8 carriles de Booth: solo generan PPs, no los suman ---
  logic [PP_WIDTH-1:0] pp     [N][NUM_PP];
  logic [NUM_PP-1:0]   pp_neg [N];

  generate
    genvar lane;
    for (lane = 0; lane < N; lane++) begin : gen_lane
      booth_radix4_pp #(
        .SRC1_WIDTH(DATA_WIDTH),
        .SRC2_WIDTH(W_WIDTH)
      ) u_booth (
        .srca     ({1'b0, data[lane]}),  // uint8 -> signed de 9 bits, siempre >= 0
        .srcb     (weight[lane]),
        .is_signed(1'b1),
        .pp       (pp[lane]),
        .pp_neg   (pp_neg[lane])
      );
    end
  endgenerate

  // --- Fila inicial del arbol ---
  // pp[lane][i] pesa 2^(2i) dentro de su carril. Entre carriles no hay corrimiento: las 8
  // multiplicaciones suman con el mismo peso.
  logic [ACC_WIDTH-1:0] rows [NUM_LEVELS+1][INIT_ROWS];

  always_comb begin
    for (int r = 0; r < INIT_ROWS; r++) rows[0][r] = '0;

    for (int l = 0; l < N; l++) begin
      // PPs sign-extendidos a 32 bits y desplazados a su columna
      for (int i = 0; i < NUM_PP; i++)
        rows[0][l*NUM_PP + i] = ACC_WIDTH'($signed(pp[l][i])) << (2*i);

      // Una fila de correccion por carril: el +1 del complemento a dos de cada PP negativo
      // va en la columna 2i. No fusiono las correcciones de dos carriles porque ambos
      // pueden tener pp_neg[i]=1 en la misma columna.
      for (int i = 0; i < NUM_PP; i++)
        rows[0][PP_ROWS + l][2*i] = pp_neg[l][i];
    end

    // El acumulador (bias o acc realimentado) es una fila mas del arbol
    rows[0][PP_ROWS + CORR_ROWS] = acc_in;
  end

  // --- Compresion Wallace: cada csa toma 3 filas y devuelve 2 (sum + carry<<1) ---
  localparam int MAX_CSAS = INIT_ROWS / 3;
  logic [ACC_WIDTH-1:0] csa_sum   [NUM_LEVELS][MAX_CSAS];
  logic [ACC_WIDTH-1:0] csa_carry [NUM_LEVELS][MAX_CSAS];

  generate
    genvar lvl, k;
    for (lvl = 0; lvl < NUM_LEVELS; lvl++) begin : gen_level
      localparam int ROWS_IN  = rows_after(INIT_ROWS, lvl);
      localparam int NUM_CSAS = ROWS_IN / 3;
      localparam int LEFTOVER = ROWS_IN % 3;

      for (k = 0; k < NUM_CSAS; k++) begin : gen_csa
        csa #(.WIDTH(ACC_WIDTH)) u_csa (
          .a        (rows[lvl][k*3]),
          .b        (rows[lvl][k*3 + 1]),
          .c_in     (rows[lvl][k*3 + 2]),
          .sum      (csa_sum[lvl][k]),
          .carry_out(csa_carry[lvl][k])
        );
      end

      always_comb begin
        for (int r = 0; r < INIT_ROWS; r++) rows[lvl+1][r] = '0;
        for (int c = 0; c < NUM_CSAS; c++) begin
          rows[lvl+1][c]            = csa_sum[lvl][c];
          rows[lvl+1][NUM_CSAS + c] = csa_carry[lvl][c] << 1;
        end
        // las filas que no completaron un grupo de 3 pasan intactas al siguiente nivel
        for (int r = 0; r < LEFTOVER; r++)
          rows[lvl+1][2*NUM_CSAS + r] = rows[lvl][NUM_CSAS*3 + r];
      end
    end
  endgenerate

  // --- Unico CPA de todo el producto punto: colapsa el par redundante (sum, carry) ---
  logic cout_unused, zero_unused, ov_unused;

  parallel_prefix_adder #(.WIDTH(ACC_WIDTH)) u_cpa (
    .srca     (rows[NUM_LEVELS][0]),
    .srcb     (rows[NUM_LEVELS][1]),
    .cin      (1'b0),
    .is_signed(1'b1),
    .result   (acc_out),
    .cout     (cout_unused),
    .zero_f   (zero_unused),
    .ov_f     (ov_unused)
  );

endmodule
