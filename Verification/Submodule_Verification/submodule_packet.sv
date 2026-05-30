/*
* submodule_packet is a class that standardizes the module packets to include print functions
*/

virtual class submodule_packet;

    pure virtual function string convert_to_string();

    virtual function void print();
        $display("%s", convert_to_string());
    endfunction

endclass