// TB de dot_product_fma8.sv: compara contra un modelo de referencia en SV
// que hace sum(w[i]*x[i]) + acc con '+' y '*' nativos en int32 signed.
`timescale 1ns/1ps
module tb_dot_product_fma8;

  logic        [7:0]  a [0:7];
  logic signed [7:0]  w [0:7];
  logic signed [31:0] acc_in;
  logic signed [31:0] acc_out;

  int errors = 0;
  int checks = 0;

  dot_product_fma8 dut (.a(a), .w(w), .acc_in(acc_in), .acc_out(acc_out));

  task automatic check(input string tag);
    logic signed [31:0] ref_acc;
    ref_acc = acc_in;
    for (int i = 0; i < 8; i++) begin
      ref_acc = ref_acc + ($signed({1'b0, a[i]}) * w[i]);
    end
    #1;
    checks++;
    if (acc_out !== ref_acc) begin
      errors++;
      $display("FAIL[%s]: acc_in=%0d a={%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d} w={%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d} -> acc_out=%0d esperado=%0d",
                tag, acc_in, a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7],
                w[0],w[1],w[2],w[3],w[4],w[5],w[6],w[7], acc_out, ref_acc);
    end
  endtask

  initial begin
    // --- casos dirigidos: extremos y el bug clasico de signo ---
    for (int i = 0; i < 8; i++) begin a[i] = 8'd15; w[i] = -8'sd128; end
    acc_in = 32'sd0; check("dirigido_wmin_pixel_max");

    for (int i = 0; i < 8; i++) begin a[i] = 8'd255; w[i] = -8'sd128; end
    acc_in = 32'sd0; check("dirigido_wmin_act_max");

    for (int i = 0; i < 8; i++) begin a[i] = 8'd0; w[i] = -8'sd1; end
    acc_in = 32'sd100; check("dirigido_pesos_menos1");

    for (int i = 0; i < 8; i++) begin a[i] = 8'd1; w[i] = 8'sd127; end
    acc_in = -32'sd1000; check("dirigido_wmax_accneg");

    for (int i = 0; i < 8; i++) begin a[i] = 8'd0; w[i] = 8'sd0; end
    acc_in = 32'sh7FFF_FFFF; check("acc_in_max");
    acc_in = 32'sh8000_0000; check("acc_in_min");

    for (int i = 0; i < 8; i++) begin a[i] = 8'd128; w[i] = 8'sd1; end
    acc_in = 32'sd0; check("bug_signo_a128_w1");

    // valor tipico del proyecto: acumulador en el rango medido en el doc (~5520)
    for (int i = 0; i < 8; i++) begin a[i] = 8'd12; w[i] = 8'sd57; end
    acc_in = 32'sd150; check("rango_tipico_doc");

    // --- modo 1: pixel uint4 (0..15), pesos en todo el rango int8 ---
    for (int t = 0; t < 3000; t++) begin
      for (int k = 0; k < 8; k++) begin
        a[k] = $urandom_range(0, 15);
        w[k] = $urandom_range(0, 255) - 128;
      end
      acc_in = $urandom;
      check("modo1_pixel");
    end

    // --- modo 2: activacion uint8 (0..255), pesos en todo el rango int8 ---
    for (int t = 0; t < 3000; t++) begin
      for (int k = 0; k < 8; k++) begin
        a[k] = $urandom_range(0, 255);
        w[k] = $urandom_range(0, 255) - 128;
      end
      acc_in = $urandom;
      check("modo2_activacion");
    end

    $display("--------------------------------------------------------");
    $display("dot_product_fma8: %0d checks, %0d errors", checks, errors);
    if (errors == 0) $display("TEST PASSED"); else $display("TEST FAILED");
    $finish;
  end

endmodule
