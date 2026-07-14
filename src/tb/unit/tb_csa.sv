// TB unitario del compresor 3:2 del usuario (src/csa.sv), reutilizado tal
// cual para el arbol de reduccion del producto punto (Variante C).
`timescale 1ns/1ps
module tb_csa;

  localparam int WIDTH      = 32;
  localparam int NUM_RANDOM = 5000;

  logic [WIDTH-1:0] a, b, c_in;
  logic [WIDTH-1:0] sum, carry_out;

  int errors = 0;
  int checks = 0;

  csa #(.WIDTH(WIDTH)) dut (.a(a), .b(b), .c_in(c_in), .sum(sum), .carry_out(carry_out));

  task automatic check(input logic [WIDTH-1:0] av, input logic [WIDTH-1:0] bv, input logic [WIDTH-1:0] cv);
    logic [WIDTH-1:0] expected;
    logic [WIDTH-1:0] reconstructed;
    a = av; b = bv; c_in = cv;
    #1;
    expected      = av + bv + cv;             // mod 2^32, igual que la suma real
    reconstructed = sum + (carry_out << 1);    // mod 2^32
    checks++;
    if (reconstructed !== expected) begin
      errors++;
      $display("FAIL: a=%0h b=%0h c_in=%0h -> sum=%0h carry_out=%0h recon=%0h esperado=%0h",
                av, bv, cv, sum, carry_out, reconstructed, expected);
    end
  endtask

  initial begin
    check(32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
    check(32'hFFFF_FFFF, 32'h0000_0000, 32'h0000_0000);
    check(32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
    check(32'h7FFF_FFFF, 32'h0000_0001, 32'h0000_0000);
    check(32'h8000_0000, 32'h8000_0000, 32'h0000_0000);
    check(32'hAAAA_AAAA, 32'h5555_5555, 32'h0000_0000);

    for (int i = 0; i < NUM_RANDOM; i++) begin
      check($urandom, $urandom, $urandom);
    end

    $display("--------------------------------------------------------");
    $display("csa: %0d checks, %0d errors", checks, errors);
    if (errors == 0) $display("TEST PASSED"); else $display("TEST FAILED");
    $finish;
  end

endmodule
