module parallel_prefix_adder #(
  parameter int WIDTH = 16                 // Ancho del adder
)(
  input  logic [WIDTH-1:0] srca,           // Operando 1
  input  logic [WIDTH-1:0] srcb,          // Operando 2
  input  logic             cin,                       // Carry de entrada
  input  logic             is_signed,            // Indica si la operacion es signed(1) o unsigned(0)
  
  
  output logic [WIDTH-1:0] result,     // Resultado
  output logic             cout,                   // Carry de salida
  output logic             zero_f,               // Bandera de cero
  output logic             ov_f                   // Bandera de overflow
);

parameter int LEVELS = $clog2(WIDTH);
// Arrays para cada nivel del parallel prefix (Kogge-Stone)
// Nivel 0 = valores iniciales, Nivel LEVELS = valores finales
logic [WIDTH-1:0] g_level [0:LEVELS];   // Generate por nivel
logic [WIDTH-1:0] p_level [0:LEVELS];   // Propagate por nivel
logic [WIDTH:0]   carry;

always_comb begin
    // Calculo de G y P del nivel 0 (se usan srca y srcb)
    for (int i = 0; i < WIDTH; i++) begin
        g_level[0][i] = srca[i] & srcb[i];   // Generate: ambos bits son 1
        p_level[0][i] = srca[i] ^ srcb[i];   // Propagate: exactamente un bit es 1
    end
    
    // Parallel Prefix Adder (Kogge-Stone)
    // Cada nivel d combina elementos a distancia 2^d
    // Se leen los generate y propagate del nivel anterior para calcular los del nivel actual
    
    for (int d = 0; d < LEVELS; d++) begin
        for (int i = 0; i < WIDTH; i++) begin
            if (i >= (1 << d)) begin
                // Combinar con elemento a distancia 2^d del nivel ANTERIOR
                g_level[d+1][i] = g_level[d][i] | (p_level[d][i] & g_level[d][i - (1 << d)]);
                p_level[d+1][i] = p_level[d][i] & p_level[d][i - (1 << d)];
            end else begin
                // Copiar sin modificar (no hay elemento a esa distancia)
                g_level[d+1][i] = g_level[d][i];
                p_level[d+1][i] = p_level[d][i];
            end
        end
    end
    
    // Cálculo de carries usando G y P finales
    // carry[i+1] = G[i] | (P[i] & cin)  -- donde G[i] ya incluye toda la cadena
    carry[0] = cin; // El primer bit de carry es el carry de entrada
    for (int i = 0; i < WIDTH; i++) begin
        carry[i+1] = g_level[LEVELS][i] | (p_level[LEVELS][i] & carry[0]);
    end
    
    
    // Suma final: result[i] = P_original[i] XOR carry[i]
    for (int i = 0; i < WIDTH; i++) begin
        result[i] = p_level[0][i] ^ carry[i];
    end
    
    
    // Flags de salida
    cout   = carry[WIDTH];
    zero_f = (result == '0);
    // Overflow: carry hacia MSB != carry desde MSB
    ov_f   = is_signed ? (carry[WIDTH-1] ^ carry[WIDTH]) : cout;
end

endmodule