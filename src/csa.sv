//Carry Save Adder (CSA) implementation in SystemVerilog

module csa #(
    parameter int WIDTH = 32
    ) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic [WIDTH-1:0] c_in,
    output logic [WIDTH-1:0] sum,
    output logic [WIDTH-1:0] carry_out
);

// La suma sin carry se obtiene con XOR
assign sum = a ^ b ^ c_in;

// El carry out se obtiene con la formula: (a & b) | (b & c_in) | (a & c_in)
assign carry_out = (a & b) | (b & c_in) | (a & c_in);

endmodule