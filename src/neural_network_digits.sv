module neural_network_digits
#(
parameter IMAGE_PIXEL_WIDTH = 4,
parameter IMAGE_HORIZONTAL_SIZE = 8,
parameter IMAGE_VERTICAL_SIZE = 8,
parameter DIGIT_WIDTH = 5)(
input logic clk ,
input logic rst ,
input logic start ,
input logic [ IMAGE_PIXEL_WIDTH -1:0] image [ IMAGE_HORIZONTAL_SIZE -1:0]
                                            [ IMAGE_VERTICAL_SIZE -1:0] , // 8x8 Digit
output logic done ,
output logic [ DIGIT_WIDTH -1:0] digit
);




endmodule 