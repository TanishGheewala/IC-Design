/*
* soc_debug_generator.sv designates an input sequence for the debug controller.
*/
`include "../../../../RTL/memory/macros.vh"

class gls_generator;

    //generator variables
    mailbox #(bit [7:0]) driver_mailbox;   //must match gls_driver
    mailbox monitor_mailbox;
    event driver_done;
    event monitor_done;
    int num_registers = 32;
    int num_memory = 32;
    int file_handle;
    int status;
    logic [7:0] current_byte;
    //2-state so their byte slices match driver_mailbox's bit [7:0] type
    //(Xcelium rejects a logic [7:0] put() into mailbox #(bit [7:0]))
    bit [31:0] image_size;
    bit [31:0] image_word;
    reg [31:0] hex_buffer [0:255];   //max image: 256 words = 1024 bytes
    string hex_file;                 //set by +HEX=<path> (run_gls.sh passes it)
    virtual core_probe core_probe_vif;
    virtual soc_interface soc_vif;

    function new();
        driver_mailbox = new();
        monitor_mailbox = new();
    endfunction

    //loads the program hex and sets image_size from the number of words it
    //actually contains, so the flash image always matches the program
    function void load_image();
        int words = 0;
        if (!$value$plusargs("HEX=%s", hex_file))
            hex_file = "gls_test.hex";   //fallback: hex in the sim run directory

        //pre-fill with X so the end of the loaded image can be found
        foreach (hex_buffer[i]) hex_buffer[i] = 'x;
        $readmemh(hex_file, hex_buffer);
        while (words < $size(hex_buffer) && !$isunknown(hex_buffer[words]))
            words++;

        if (words == 0)
            $fatal(1, "[Generator] no program words loaded from '%s' (missing or empty hex?)", hex_file);
        image_size = words * 4;
        $display("T=%0t [Generator] loaded %0d words (%0d bytes) from %s", $time, words, image_size, hex_file);
    endfunction

    //tests all registers and memory values coming through debug controller
    virtual task debug_instruction_sequence();
        soc_packet soc_item;

        load_image();   //before any UART traffic, so a bad hex fails immediately
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

        //image_size was set by load_image() from the hex word count
        for(int j = 0; j < 4; j++) begin
            @(driver_done);
            case(j)
                0:  driver_mailbox.put(image_size[31:24]);
                1:  driver_mailbox.put(image_size[23:16]);
                2:  driver_mailbox.put(image_size[15:8]);
                3:  driver_mailbox.put(image_size[7:0]);
            endcase
        end

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

        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_HALT;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);
        @(driver_done);

        soc_item = new;
        //turns on register contraint for debug address
        soc_item.c_registers.constraint_mode(1);
        soc_item.c_memory.constraint_mode(0);
        if (!soc_item.randomize())
            $fatal(1, "[Generator] randomize() failed for RETURN_REG address");
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

        //loops through first 32 memory locations and checks debug controller returns correct value for each
        soc_item = new;
        //turns on register contraint for debug address
        soc_item.c_registers.constraint_mode(0);
        soc_item.c_memory.constraint_mode(1);
        if (!soc_item.randomize())
            $fatal(1, "[Generator] randomize() failed for RETURN_MEM address");
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

        //resumes core and ends debug check
        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_RESUME;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);
        @(driver_done);
    endtask
    
endclass