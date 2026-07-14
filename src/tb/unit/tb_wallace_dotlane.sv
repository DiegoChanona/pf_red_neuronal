// TB unitario de wallace_tree_mult.sv en la instanciacion exacta que se
// usaria como celda multiplicadora por carril del producto punto:
// SRC1_WIDTH=9 (operando 'a' NO signado, pixel uint4 o activacion uint8,
// zero-extendido con un 0 en el bit 8) x SRC2_WIDTH=8 (peso int8, con signo
// nativo), siempre con is_signed=1.
//
// La zero-extension de 'a' es la defensa contra el bug clasico de signedness:
// si 'a' se pasara con su ancho nativo de 8 bits bajo is_signed=1, un valor
// como 128 (bit7=1, activacion valida 0..255) se leeria como -128. Con el
// bit 9 extra en cero, 128 sigue siendo +128 aunque is_signed=1.
`timescale 1ns/1ps
module tb_wallace_dotlane;

  localparam int SRC1_WIDTH = 9;
  localparam int SRC2_WIDTH = 8;
  localparam int NUM_RANDOM = 4000;

  logic [SRC1_WIDTH-1:0] srca;   // {1'b0, a_raw8}
  logic [SRC2_WIDTH-1:0] srcb;   // peso int8, bits nativos
  logic                  is_signed;
  logic [SRC1_WIDTH+SRC2_WIDTH-1:0] result;

  int errors = 0;
  int checks = 0;

  wallace_tree_mult #(.SRC1_WIDTH(SRC1_WIDTH), .SRC2_WIDTH(SRC2_WIDTH)) dut (
    .srca(srca), .srcb(srcb), .is_signed(is_signed), .result(result)
  );

  task automatic check(input logic [7:0] a_raw, input logic signed [7:0] w, input string tag);
    logic signed [SRC1_WIDTH+SRC2_WIDTH-1:0] expected;
    srca      = {1'b0, a_raw};
    srcb      = w;
    is_signed = 1'b1;
    #1;
    expected = $signed({1'b0, a_raw}) * $signed(w);
    checks++;
    if (result !== expected) begin
      errors++;
      $display("FAIL[%s]: a_raw=%0d w=%0d -> result=%0d esperado=%0d",
                tag, a_raw, w, $signed(result), expected);
    end
  endtask

  initial begin
    // casos dirigidos: extremos de peso/operando y el caso que atrapa el bug de signo
    check(8'd0,   -8'sd128, "a0_wmin");
    check(8'd255, -8'sd128, "amax8_wmin");
    check(8'd15,  -8'sd128, "amax4_wmin");
    check(8'd255,  8'sd127, "amax8_wmax");
    check(8'd0,    8'sd127, "a0_wmax");
    check(8'd1,   -8'sd1,   "a1_wmenos1");
    check(8'd128,  8'sd1,   "a128_w1_bug_signo");  // a con bit7=1 pero unsigned -> debe dar +128, no -128

    // modo "capa1": a limitado a 0..15 (pixel uint4), pesos en todo el rango int8
    for (int i = 0; i < NUM_RANDOM; i++) begin
      check($urandom_range(0, 15), $urandom_range(0, 255) - 128, "modo1_pixel");
    end

    // modo "capa2": a en 0..255 (activacion uint8), pesos en todo el rango int8
    for (int i = 0; i < NUM_RANDOM; i++) begin
      check($urandom_range(0, 255), $urandom_range(0, 255) - 128, "modo2_activacion");
    end

    $display("--------------------------------------------------------");
    $display("wallace_tree_mult (carril 9x8 del producto punto): %0d checks, %0d errors", checks, errors);
    if (errors == 0) $display("TEST PASSED"); else $display("TEST FAILED");
    $finish;
  end

endmodule
