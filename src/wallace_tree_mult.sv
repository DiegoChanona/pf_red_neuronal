// Multiplicador Wallace Tree con Booth Radix-4
// Booth reduce PPs a la mitad, Wallace comprime con CSAs hasta quedar 2 filas

module wallace_tree_mult #(
  parameter int SRC1_WIDTH = 8,
  parameter int SRC2_WIDTH = SRC1_WIDTH
) (
  input  logic [SRC1_WIDTH-1:0]            srca,
  input  logic [SRC2_WIDTH-1:0]            srcb,
  input  logic                             is_signed,
  output logic [SRC1_WIDTH+SRC2_WIDTH-1:0] result
);


  localparam int RESULT_WIDTH = SRC1_WIDTH + SRC2_WIDTH;
  localparam int NUM_PP       = (SRC2_WIDTH + 2) / 2;
  localparam int PP_WIDTH     = SRC1_WIDTH + 2;
  localparam int INITIAL_ROWS = NUM_PP + 1;  // PPs + fila de correccion

  // Calcula filas restantes tras 'lvl' niveles de compresion 3:2
  function automatic int rows_after(int n, int lvl);
    for (int i = 0; i < lvl; i++)
      n = 2*(n/3) + (n%3);
    return n;
  endfunction

  // // Niveles Wallace: ceil(log_{1.5}(n/2))

 
 localparam int NUM_LEVELS = $clog2(INITIAL_ROWS) + $clog2((INITIAL_ROWS + 2) / 2);


  // --- Booth Radix-4: genera NUM_PP productos parciales ---
  logic [PP_WIDTH-1:0] pp     [NUM_PP];
  logic [NUM_PP-1:0]   pp_neg;

  booth_radix4_pp #(
    .SRC1_WIDTH(SRC1_WIDTH),
    .SRC2_WIDTH(SRC2_WIDTH)
  ) u_booth (
    .srca(srca), .srcb(srcb), .is_signed(is_signed),
    .pp(pp), .pp_neg(pp_neg)
  );

  // --- Alineacion de PPs ---
  // pp[i] tiene peso 2^(2i), se desplaza a su posicion
  // pp_neg[i]=1 indica complemento, se suma 1 en columna 2i
  logic [RESULT_WIDTH-1:0] rows [NUM_LEVELS+1][INITIAL_ROWS];

  always_comb begin
    for (int i = 0; i < INITIAL_ROWS; i++) rows[0][i] = '0;
    for (int i = 0; i < NUM_PP; i++)
      rows[0][i] = RESULT_WIDTH'($signed(pp[i])) << (2 * i);
    for (int i = 0; i < NUM_PP; i++)
      rows[0][NUM_PP][2*i] = pp_neg[i];
  end

  // --- Compresion Wallace con CSAs ---
  // Cada CSA toma 3 filas -> sum + carry<<1 (2 filas)
  // Filas sobrantes (mod 3) pasan directo
  localparam int MAX_CSAS = INITIAL_ROWS / 3;
  logic [RESULT_WIDTH-1:0] csa_sum   [NUM_LEVELS][MAX_CSAS];
  logic [RESULT_WIDTH-1:0] csa_carry [NUM_LEVELS][MAX_CSAS];

  generate
    genvar lvl, csa_idx;
    for (lvl = 0; lvl < NUM_LEVELS; lvl++) begin : gen_level
      localparam int ROWS_IN  = rows_after(INITIAL_ROWS, lvl);
      localparam int NUM_CSAS = ROWS_IN / 3;
      localparam int LEFTOVER = ROWS_IN % 3;

      for (csa_idx = 0; csa_idx < NUM_CSAS; csa_idx++) begin : gen_csa
        csa #(.WIDTH(RESULT_WIDTH)) u_csa (
          .a        (rows[lvl][csa_idx*3]),
          .b        (rows[lvl][csa_idx*3 + 1]),
          .c_in     (rows[lvl][csa_idx*3 + 2]),
          .sum      (csa_sum[lvl][csa_idx]),
          .carry_out(csa_carry[lvl][csa_idx])
        );
      end

      // Conectar al siguiente nivel
      always_comb begin
        integer i, ci, r;
        for (i = 0; i < INITIAL_ROWS; i++) rows[lvl+1][i] = '0;
        for (ci = 0; ci < NUM_CSAS; ci++) begin
          rows[lvl+1][ci]            = csa_sum[lvl][ci];
          rows[lvl+1][NUM_CSAS + ci] = csa_carry[lvl][ci] << 1;
        end
        for (r = 0; r < LEFTOVER; r++)
          rows[lvl+1][2*NUM_CSAS + r] = rows[lvl][NUM_CSAS*3 + r];
      end
    end
  endgenerate

  // --- Suma final (Kogge-Stone) ---
  logic cout_unused, zero_unused, ov_unused;

  parallel_prefix_adder #(.WIDTH(RESULT_WIDTH)) u_final_adder (
    .srca     (rows[NUM_LEVELS][0]),
    .srcb     (rows[NUM_LEVELS][1]),
    .cin      (1'b0),
    .is_signed(is_signed),
    .result   (result),
    .cout     (cout_unused),
    .zero_f   (zero_unused),
    .ov_f     (ov_unused)
  );

endmodule
