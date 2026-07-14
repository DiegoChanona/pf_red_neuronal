module rom_mem_param #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH = 128,  // 128 palabras
    parameter FILE_PATH = "..\\asm_code\\matriz_x_vector_uart.hex"
)(
    input  logic [ADDR_WIDTH-1:0] address,
    output logic [DATA_WIDTH-1:0] data_out
);

    localparam ROM_ADDR_WIDTH = $clog2(MEM_DEPTH);

    logic [ROM_ADDR_WIDTH-1:0] rom_address;
    // Byte addressing: se descartan los 2 LSB para direccionar por palabra de 32 bits.
    assign rom_address = address[ROM_ADDR_WIDTH+1:2];

    logic [DATA_WIDTH-1:0] rom_mem [MEM_DEPTH-1:0];

    initial begin
        $readmemh(FILE_PATH, rom_mem);
    end

    // Lectura combinacional
    assign data_out = rom_mem[rom_address];

endmodule