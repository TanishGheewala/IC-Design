/*
* soc_debug_generator.sv designates an input sequence for the debug controller.
*/
`include "../../../../RTL/memory/macros.vh"

class soc_debug_generator;

    //generator variables
    mailbox driver_mailbox;
    mailbox monitor_mailbox;
    event driver_done;
    event monitor_done;
    int num_registers = 32;
    int num_memory = 32;
    int file_handle;
    int status;
    logic [7:0] current_byte;
    logic [31:0] image_size;
    logic [31:0] image_word;
    reg [31:0] hex_buffer [0:255]; 
    virtual core_probe core_probe_vif;
    virtual soc_interface soc_vif;

    function new();
        driver_mailbox = new();
        monitor_mailbox = new();
    endfunction
    
    //tests all registers and memory values coming through debug controller
    virtual task debug_instruction_sequence();
        soc_packet soc_item;

        $display ("T=%0t [Test] Starting Sequence ...", $time);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::NOP;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_HALT;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::FLASH_WRITE;
        driver_mailbox.put(soc_item.debug_instruction);

        image_size = 160;
        for(int j = 0; j < 4; j++) begin
            @(driver_done);
            case(j)
                0:  driver_mailbox.put(image_size[31:24]);
                1:  driver_mailbox.put(image_size[23:16]);
                2:  driver_mailbox.put(image_size[15:8]);
                3:  driver_mailbox.put(image_size[7:0]);
            endcase
        end

        $readmemh("debug_test.hex", hex_buffer);
        for(int i = 0; i < (image_size/4); i++) begin
            image_word = hex_buffer[i];
            for(int j = 0; j < 4; j++) begin
                @(driver_done);
                case(j)
                    0:  driver_mailbox.put(image_word[31:24]);
                    1:  driver_mailbox.put(image_word[23:16]);
                    2:  driver_mailbox.put(image_word[15:8]);
                    3:  driver_mailbox.put(image_word[7:0]);
                endcase
            end
        end
        

        //resumes core and ends debug check
        @(posedge core_probe_vif.flash_write_done);
        #1000;

        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_RESUME;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        @(driver_done);
        soc_vif.rst_n = 0;
        repeat (10) @(posedge soc_vif.clk);
        soc_vif.rst_n = 1;

        //lets code run
        @(posedge core_probe_vif.boot_done);
        #4000;

        $display("mem_loc: %0h", core_probe_vif.memory[4]);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_HALT;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        //loops through all registers and checks debug controller returns correct value for each
        @(driver_done);
        for(int i = 0; i < num_registers; i++) begin
            soc_item = new;
            //turns on register contraint for debug address
            soc_item.c_registers.constraint_mode(1);
            soc_item.c_memory.constraint_mode(0);
            soc_item.randomize();
            soc_item.debug_instruction = soc_packet::RETURN_REG;
            driver_mailbox.put(soc_item.debug_instruction);
            monitor_mailbox.put(soc_item);

            //sends address in sections over uart
            for(int j = 0; j < 4; j++) begin
                @(driver_done);
                case(j)
                    0:  driver_mailbox.put(soc_item.debug_address[31:24]);
                    1:  driver_mailbox.put(soc_item.debug_address[23:16]);
                    2:  driver_mailbox.put(soc_item.debug_address[15:8]);
                    3:  driver_mailbox.put(soc_item.debug_address[7:0]);
                endcase
            end
            @(monitor_done);
        end
        //loops through first 32 memory locations and checks debug controller returns correct value for each
        for(int i = 0; i < num_memory; i++) begin
            soc_item = new;
            //turns on register contraint for debug address
            soc_item.c_registers.constraint_mode(0);
            soc_item.c_memory.constraint_mode(1);
            soc_item.randomize();
            soc_item.debug_address = soc_item.debug_address;
            soc_item.debug_instruction = soc_packet::RETURN_MEM;
            driver_mailbox.put(soc_item.debug_instruction);
            monitor_mailbox.put(soc_item);

            //sends address in sections over uart
            for(int j = 0; j < 4; j++) begin
                @(driver_done);
                case(j)
                    0:  driver_mailbox.put(soc_item.debug_address[31:24]);
                    1:  driver_mailbox.put(soc_item.debug_address[23:16]);
                    2:  driver_mailbox.put(soc_item.debug_address[15:8]);
                    3:  driver_mailbox.put(soc_item.debug_address[7:0]);
                endcase
            end
            @(monitor_done);
        end
        
        //checks gpio pins
        //DIR
        soc_item = new;
        soc_item.debug_address = 31'h00001000;
        soc_item.debug_instruction = soc_packet::RETURN_MEM;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        //sends address in sections over uart
        for(int j = 0; j < 4; j++) begin
            @(driver_done);
            case(j)
                0:  driver_mailbox.put(soc_item.debug_address[31:24]);
                1:  driver_mailbox.put(soc_item.debug_address[23:16]);
                2:  driver_mailbox.put(soc_item.debug_address[15:8]);
                3:  driver_mailbox.put(soc_item.debug_address[7:0]);
            endcase
        end
        @(monitor_done);
        
        //OUT
        soc_item = new;
        soc_item.debug_address = 31'h00001004;
        soc_item.debug_instruction = soc_packet::RETURN_MEM;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        //sends address in sections over uart
        for(int j = 0; j < 4; j++) begin
            @(driver_done);
            case(j)
                0:  driver_mailbox.put(soc_item.debug_address[31:24]);
                1:  driver_mailbox.put(soc_item.debug_address[23:16]);
                2:  driver_mailbox.put(soc_item.debug_address[15:8]);
                3:  driver_mailbox.put(soc_item.debug_address[7:0]);
            endcase
        end
        @(monitor_done);

        //IN
        soc_item = new;
        soc_item.debug_address = 31'h00001008;
        soc_item.debug_instruction = soc_packet::RETURN_MEM;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        //sends address in sections over uart
        for(int j = 0; j < 4; j++) begin
            @(driver_done);
            case(j)
                0:  driver_mailbox.put(soc_item.debug_address[31:24]);
                1:  driver_mailbox.put(soc_item.debug_address[23:16]);
                2:  driver_mailbox.put(soc_item.debug_address[15:8]);
                3:  driver_mailbox.put(soc_item.debug_address[7:0]);
            endcase
        end
        @(monitor_done);

        //resumes core and ends debug check
        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_RESUME;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::NOP;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        @(driver_done);
    endtask
    
endclass