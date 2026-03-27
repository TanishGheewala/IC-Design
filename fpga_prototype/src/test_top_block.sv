module test_top_block(
                        input clk, 
                        input uart_in, 
                        output logic [31:0] alu_out,
                        output logic transmission_done
                     );
    uart_interface uart_if();
    alu_interface alu_if();
    
    uart_rec #(.CLK_RATE(100000000), .BAUDRATE(9600))
        UR00(.uart_if(uart_if));
    
    alu ALU00(.alu_if(alu_if));
    
    logic [6:0] alu_op = 0;
    logic [31:0] alu_in0 = 0;
    logic [31:0] alu_in1 = 0;
    logic [1:0] uart_counter = 0;
    logic out_delay = 0;
    
    always_comb begin
        alu_if.in_data_0 = alu_in0;
        alu_if.in_data_1 = alu_in1;
        alu_if.alu_opcode = alu_op;
        uart_if.clk = clk;
        uart_if.serial_data = uart_in;
        transmission_done = uart_if.uart_tran_done;
    end
    
    always_ff @(posedge clk) begin
        if(uart_if.uart_tran_done == 1) begin
            case(uart_counter)
                2'b00: alu_op <= uart_if.byte_data;
                2'b01: alu_in0 <= uart_if.byte_data;
                2'b10: alu_in1 <= uart_if.byte_data;
            endcase
            
            if(uart_counter == 2) begin
                uart_counter <= 0;
                out_delay <= out_delay + 1;
            end else begin
                uart_counter <= uart_counter + 1;
            end
        end
        
        if(out_delay != 0) begin
            alu_out <= alu_if.out_data;
            out_delay <= 0;
        end            
    end
endmodule