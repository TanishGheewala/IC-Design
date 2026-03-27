`timescale 1ns/1ps
/*
* alu_block: wrapper for vivado block design for interacting with arm processro
* through vitus
*/
module alu_block(
                    input wire [5:0] alu_op,
                    input wire [31:0] alu_in0,
                    input wire [31:0] alu_in1,
                    output wire [31:0] alu_out
                );
                
    localparam WIDTH = 32;
    
    // Signed/Unsigned
    reg [WIDTH-1:0]        a_u, b_u;
    reg signed [WIDTH-1:0] a_s, b_s;
    reg [WIDTH-1:0]        result;

    // Op-Casting
    always begin
    a_u = alu_in0;
    b_u = alu_in1;
    a_s = $signed(alu_in0);
    b_s = $signed(alu_in1);
    end

    // Combinational Logic
    always begin
        result = 0; // default result = '0;
        case(alu_op)

        // Arithmetic
        6'b011001: result = a_u + b_u; // ADD
        6'b011010: result = a_u - b_u; // SUB

        // Bitwise Logic
        6'b011011: result = a_u & b_u; // AND
        6'b011100: result = a_u | b_u; // OR    
        6'b011101: result = a_u ^ b_u; // XOR

        // Shifts
        6'b011110: result = a_u << b_u[4:0]; // SLL
        6'b011111: result = a_u >> b_u[4:0]; // SRL
        6'b100000: result = a_s >>> b_u[4:0]; // SRA

        // Comparisons
        6'b100001: result = (a_s < b_s) ? 32'd1 : 32'd0; // SLT
        6'b100010: result = (a_u < b_u) ? 32'd1 : 32'd0; // SLTU

        // Passthrough
        6'b100011: result = a_u; // Pass A
        6'b100100: result = b_u; // Pass B

        default: result = 0;
        endcase
    end
    
    assign alu_out = result;
endmodule