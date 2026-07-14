// TB unitario de requant_unit.sv: ReLU -> >>>5 -> clamp(255) -> uint8.
`timescale 1ns/1ps
module tb_requant_unit;

  localparam int SHIFT1 = 5;

  logic signed [31:0] acc;
  logic        [7:0]  act;

  int errors = 0;
  int checks = 0;

  requant_unit #(.SHIFT1(SHIFT1), .CLAMP_MAX(255)) dut (.acc(acc), .act(act));

  task automatic check(input logic signed [31:0] accv, input string tag);
    logic signed [63:0] relu;
    logic signed [63:0] shifted;
    logic [7:0] expected;
    acc = accv;
    #1;
    relu     = (accv < 0) ? 0 : accv;
    shifted  = relu >>> SHIFT1;
    expected = (shifted > 255) ? 8'd255 : shifted[7:0];
    checks++;
    if (act !== expected) begin
      errors++;
      $display("FAIL[%s]: acc=%0d -> act=%0d esperado=%0d", tag, accv, act, expected);
    end
  endtask

  initial begin
    // negativos -> 0
    check(-1, "neg_menos1");
    check(-32, "neg_menos32");
    check(-1000000, "neg_grande");
    check(32'sh8000_0000, "MIN_INT");

    // frontera exacta de la saturacion (255*32=8160)
    check(32'sd8159, "shift_254_no_satura");
    check(32'sd8160, "shift_255_exacto_no_satura");
    check(32'sd8191, "shift_255_floor_no_satura");
    check(32'sd8192, "shift_256_satura");
    check(32'sd100000, "muy_saturado");

    // valores tipicos que no saturan
    check(32'sd0, "cero");
    check(32'sd31, "shift_0");
    check(32'sd32, "shift_1");
    check(32'sd5520, "valor_max_medido_doc");

    // MAX_INT: satura
    check(32'sh7FFF_FFFF, "MAX_INT");

    // barrido aleatorio sobre todo el rango de int32
    for (int i = 0; i < 20000; i++) begin
      check($random, "random");
    end

    $display("--------------------------------------------------------");
    $display("requant_unit: %0d checks, %0d errors", checks, errors);
    if (errors == 0) $display("TEST PASSED"); else $display("TEST FAILED");
    $finish;
  end

endmodule
