// TB dedicado de booth_radix4_pp.sv en la instanciacion 9x8 que usara el
// producto punto fusionado (dot_product_fma8): reconstruye
// sum(pp[i]<<2i) + sum(pp_neg[i]<<2i) y lo compara contra a*w nativo,
// incluyendo el caso mixto unsigned(a, zero-extendido a 9 bits)*signed(w)
// con is_signed=1 fijo (el bug de signedness mixto es el punto critico).
`timescale 1ns/1ps
module tb_booth_radix4_pp;

  localparam int SRC1_WIDTH = 9;
  localparam int SRC2_WIDTH = 8;
  localparam int NUM_PP     = (SRC2_WIDTH + 2) / 2;
  localparam int PP_WIDTH   = SRC1_WIDTH + 2;

  logic [SRC1_WIDTH-1:0] srca;
  logic [SRC2_WIDTH-1:0] srcb;
  logic is_signed;
  logic [PP_WIDTH-1:0] pp [NUM_PP];
  logic [NUM_PP-1:0]   pp_neg;

  int errors = 0;
  int checks = 0;

  booth_radix4_pp #(.SRC1_WIDTH(SRC1_WIDTH), .SRC2_WIDTH(SRC2_WIDTH)) dut (
    .srca(srca), .srcb(srcb), .is_signed(is_signed), .pp(pp), .pp_neg(pp_neg)
  );

  task automatic check(input logic [7:0] a_raw, input logic signed [7:0] w, input string tag);
    logic signed [31:0] recon;
    logic signed [31:0] expected;
    srca = {1'b0, a_raw};   // zero-extension: pixel uint4 o activacion uint8 -> 9 bits, MSB=0
    srcb = w;
    is_signed = 1'b1;
    #1;
    recon = 0;
    for (int i = 0; i < NUM_PP; i++) begin
      recon += (32'($signed(pp[i])) << (2*i));
      recon += (32'(pp_neg[i]) << (2*i));
    end
    expected = $signed({1'b0, a_raw}) * $signed(w);
    checks++;
    if (recon !== expected) begin
      errors++;
      $display("FAIL[%s]: a_raw=%0d w=%0d -> recon=%0d esperado=%0d", tag, a_raw, w, recon, expected);
    end
  endtask

  initial begin
    check(8'd0,   -8'sd128, "a0_wmin");
    check(8'd255, -8'sd128, "amax8_wmin");
    check(8'd15,  -8'sd128, "amax4_wmin");
    check(8'd255,  8'sd127, "amax8_wmax");
    check(8'd0,    8'sd127, "a0_wmax");
    check(8'd1,   -8'sd1,   "a1_wmenos1");
    check(8'd128,  8'sd1,   "a128_w1_bug_signo"); // bit7=1 pero 'a' es unsigned -> debe dar +128

    for (int i = 0; i < 4000; i++) begin
      check($urandom_range(0, 15), $urandom_range(0, 255) - 128, "modo1_pixel");
    end
    for (int i = 0; i < 4000; i++) begin
      check($urandom_range(0, 255), $urandom_range(0, 255) - 128, "modo2_activacion");
    end

    $display("--------------------------------------------------------");
    $display("booth_radix4_pp (9x8, is_signed=1): %0d checks, %0d errors", checks, errors);
    if (errors == 0) $display("TEST PASSED"); else $display("TEST FAILED");
    $finish;
  end

endmodule
