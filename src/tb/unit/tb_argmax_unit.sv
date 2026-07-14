// TB unitario de argmax_unit.sv: comparador signed corriendo, init en
// 32'h8000_0000, empate gana el primer indice.
`timescale 1ns/1ps
module tb_argmax_unit;

  localparam int NUM_CLASSES = 10;
  localparam int INDEX_WIDTH = 4;

  logic clk, rst, clear, valid;
  logic signed [31:0]     score;
  logic [INDEX_WIDTH-1:0] index;
  logic signed [31:0]     best_score;
  logic [INDEX_WIDTH-1:0] best_index;

  int errors = 0;
  int checks = 0;

  argmax_unit #(.NUM_CLASSES(NUM_CLASSES), .INDEX_WIDTH(INDEX_WIDTH)) dut (
    .clk(clk), .rst(rst), .clear(clear), .valid(valid),
    .score(score), .index(index),
    .best_score(best_score), .best_index(best_index)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  task automatic run_pass(input logic signed [31:0] scores[NUM_CLASSES], input string tag);
    logic signed [31:0] ref_best_score;
    int ref_best_index;
    ref_best_score = 32'sh8000_0000;
    ref_best_index = 0;
    for (int i = 0; i < NUM_CLASSES; i++) begin
      if (scores[i] > ref_best_score) begin
        ref_best_score = scores[i];
        ref_best_index = i;
      end
    end

    @(posedge clk);
    clear <= 1'b1;
    @(posedge clk);
    clear <= 1'b0;
    for (int i = 0; i < NUM_CLASSES; i++) begin
      valid <= 1'b1;
      score <= scores[i];
      index <= i[INDEX_WIDTH-1:0];
      @(posedge clk);
    end
    valid <= 1'b0;
    @(posedge clk);

    checks++;
    if (best_index !== ref_best_index[INDEX_WIDTH-1:0] || best_score !== ref_best_score) begin
      errors++;
      $display("FAIL[%s]: best_index=%0d (esperado %0d)  best_score=%0d (esperado %0d)",
                tag, best_index, ref_best_index, best_score, ref_best_score);
    end
  endtask

  initial begin
    logic signed [31:0] s [NUM_CLASSES];

    rst = 1; clear = 0; valid = 0; score = 0; index = 0;
    repeat (2) @(posedge clk);
    rst = 0;

    s = '{-5, 10, 3, 100, -1, 0, 99, 100, 2, -100};
    run_pass(s, "empate_100_en_3_y_7_gana_3");

    s = '{50, 50, 50, 50, 50, 50, 50, 50, 50, 50};
    run_pass(s, "empate_total_gana_0");

    s = '{1,2,3,4,5,6,7,8,9,1000};
    run_pass(s, "max_al_final");

    s = '{-5,-3,-100,-1,-50,-2,-999,-4,-7,-6};
    run_pass(s, "todos_negativos_gana_indice3");

    s = '{500,-1,-2,-3,-4,-5,-6,-7,-8,-9};
    run_pass(s, "max_al_inicio");

    for (int t = 0; t < 200; t++) begin
      for (int i = 0; i < NUM_CLASSES; i++) s[i] = $random;
      run_pass(s, $sformatf("random_%0d", t));
    end

    $display("--------------------------------------------------------");
    $display("argmax_unit: %0d checks, %0d errors", checks, errors);
    if (errors == 0) $display("TEST PASSED"); else $display("TEST FAILED");
    $finish;
  end

endmodule
