// Booth Radix-4: genera N/2 productos parciales
// Soporta signed/unsigned y anchos pares/impares

module booth_radix4_pp #(
  parameter int SRC1_WIDTH = 8,
  parameter int SRC2_WIDTH = 8
)(
  input  logic [SRC1_WIDTH-1:0]           srca,
  input  logic [SRC2_WIDTH-1:0]           srcb,
  input  logic                            is_signed,
  output logic [SRC1_WIDTH+1:0]           pp [(SRC2_WIDTH+2)/2],
  output logic [(SRC2_WIDTH+2)/2-1:0]     pp_neg
);
  localparam int NUM_PP   = (SRC2_WIDTH + 2) / 2;  // Para uso interno
  localparam int PP_WIDTH = SRC1_WIDTH + 2;

  // Multiplos de A
  logic [PP_WIDTH-1:0] a_ext, a_2x, neg_a, neg_a_2x;
  
  // B extendido: {2 bits arriba, srcb, b[-1]=0}
  logic [SRC2_WIDTH+2:0] b_ext;

  //Valores de A para cada caso de codificacion Booth:
  always_comb begin
    a_ext    = is_signed ? {{2{srca[SRC1_WIDTH-1]}}, srca} : {{2{1'b0}}, srca};
    a_2x     = a_ext << 1;
    neg_a    = ~a_ext;      // -A (el +1 va en pp_neg)
    neg_a_2x = ~a_2x;       // -2A
  end

  // Se extiende y desplaza srcb para formar b_ext, que se recorre de 3 en 3 bits
  always_comb begin
    b_ext = is_signed ? {{2{srcb[SRC2_WIDTH-1]}}, srcb, 1'b0}
                      : {2'b0, srcb, 1'b0};
  end

  // Decodificacion Booth y generacion de PPs
  always_comb begin
    for (int i = 0; i < NUM_PP; i++) begin
      case (b_ext[2*i+2 -: 3])
        3'b000: begin pp[i] = '0;       pp_neg[i] = 1'b0; end  // 0
        3'b001: begin pp[i] = a_ext;    pp_neg[i] = 1'b0; end  // +A
        3'b010: begin pp[i] = a_ext;    pp_neg[i] = 1'b0; end  // +A
        3'b011: begin pp[i] = a_2x;     pp_neg[i] = 1'b0; end  // +2A
        3'b100: begin pp[i] = neg_a_2x; pp_neg[i] = 1'b1; end  // -2A
        3'b101: begin pp[i] = neg_a;    pp_neg[i] = 1'b1; end  // -A
        3'b110: begin pp[i] = neg_a;    pp_neg[i] = 1'b1; end  // -A
        3'b111: begin pp[i] = '0;       pp_neg[i] = 1'b0; end  // 0
      endcase
    end
  end

endmodule
