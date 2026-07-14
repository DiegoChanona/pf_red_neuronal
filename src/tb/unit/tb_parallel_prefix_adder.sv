// TB unitario del Kogge-Stone del usuario (src/parallel_prefix_adder.sv) en
// WIDTH=32, que es la instanciacion que usaremos como CPA final del arbol de
// reduccion del producto punto (acumulador int32).
`timescale 1ns/1ps
module tb_parallel_prefix_adder;

  localparam int WIDTH      = 32;
  localparam int NUM_RANDOM = 5000;

  logic [WIDTH-1:0] srca, srcb;
  logic cin, is_signed;
  logic [WIDTH-1:0] result;
  logic cout, zero_f, ov_f;

  int errors = 0;
  int checks = 0;

  parallel_prefix_adder #(.WIDTH(WIDTH)) dut (
    .srca(srca), .srcb(srcb), .cin(cin), .is_signed(is_signed),
    .result(result), .cout(cout), .zero_f(zero_f), .ov_f(ov_f)
  );

  task automatic check(input logic [WIDTH-1:0] av, input logic [WIDTH-1:0] bv, input logic cv, input logic sgn, input string tag);
    logic [WIDTH:0]        wide;
    logic                  exp_cout, exp_zero;
    logic signed [WIDTH-1:0] sa, sb;
    logic signed [WIDTH:0]   sa_ext, sb_ext, wide_signed;
    logic                    exp_ov;

    srca = av; srcb = bv; cin = cv; is_signed = sgn;
    #1;

    wide     = {1'b0, av} + {1'b0, bv} + {{WIDTH{1'b0}}, cv};
    exp_cout = wide[WIDTH];
    exp_zero = (wide[WIDTH-1:0] == '0);

    sa = av; sb = bv;
    sa_ext = {sa[WIDTH-1], sa};
    sb_ext = {sb[WIDTH-1], sb};
    wide_signed = sa_ext + sb_ext + {{WIDTH{1'b0}}, cv};
    exp_ov = sgn ? (wide_signed[WIDTH] != wide_signed[WIDTH-1]) : exp_cout;

    checks++;
    if (result !== wide[WIDTH-1:0]) begin
      errors++;
      $display("FAIL[%s] SUMA: a=%0h b=%0h cin=%0b -> result=%0h esperado=%0h", tag, av, bv, cv, result, wide[WIDTH-1:0]);
    end
    if (cout !== exp_cout) begin
      errors++;
      $display("FAIL[%s] COUT: a=%0h b=%0h cin=%0b -> cout=%0b esperado=%0b", tag, av, bv, cv, cout, exp_cout);
    end
    if (zero_f !== exp_zero) begin
      errors++;
      $display("FAIL[%s] ZERO: a=%0h b=%0h cin=%0b -> zero_f=%0b esperado=%0b", tag, av, bv, cv, zero_f, exp_zero);
    end
    if (ov_f !== exp_ov) begin
      errors++;
      $display("FAIL[%s] OVF(is_signed=%0b): a=%0h b=%0h cin=%0b -> ov_f=%0b esperado=%0b", tag, sgn, av, bv, cv, ov_f, exp_ov);
    end
  endtask

  initial begin
    check(32'h0000_0000, 32'h0000_0000, 1'b0, 1'b0, "cero");
    check(32'hFFFF_FFFF, 32'h0000_0001, 1'b0, 1'b0, "wrap_unsigned");
    check(32'h7FFF_FFFF, 32'h0000_0001, 1'b0, 1'b1, "overflow_signed_pos");
    check(32'h8000_0000, 32'hFFFF_FFFF, 1'b0, 1'b1, "min_mas_menos1");
    check(32'h8000_0000, 32'h8000_0000, 1'b0, 1'b1, "min_mas_min_overflow");
    check(32'hFFFF_FFFF, 32'hFFFF_FFFF, 1'b1, 1'b0, "menos1_menos1_cin1");
    check(32'h7FFF_FFFF, 32'h7FFF_FFFF, 1'b1, 1'b1, "max_mas_max_cin1_overflow");

    for (int i = 0; i < NUM_RANDOM; i++) begin
      check($urandom, $urandom, $urandom % 2, $urandom % 2, "random");
    end

    $display("--------------------------------------------------------");
    $display("parallel_prefix_adder: %0d checks, %0d errors", checks, errors);
    if (errors == 0) $display("TEST PASSED"); else $display("TEST FAILED");
    $finish;
  end

endmodule
