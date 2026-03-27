/*
* alu_sequence generates a sequence of edgecase and randomized bits to
* send to alu.
*/
class alu_sequence extends uvm_sequence;

    //required section for registering with UVM factory
    `uvm_object_utils(alu_sequence)
    function new(string name="alu_sequence");
        super.new(name);
    endfunction

    int num_of_packets = 100;

    //generates random data packets to send to alu
    //still need to add edge cases
    virtual task body();
        for(int i=0; i < num_of_packets; i++) begin

            //standerd way of initializing class in UVM
            alu_item m_alu_item = alu_item::type_id::create("m_alu_item");

            //blocking statement for sending data to driver
            //wait till driver ready
            start_item(m_alu_item);
            m_alu_item.randomize();
            `uvm_info("SEQ", $sformatf("Generate sequence item:"), UVM_HIGH)
            finish_item(m_alu_item);
        end

        //uvm_info is used for console logging of UVM
        `uvm_info("SEQ", $sformatf("Finish sequence generation: %d items", num_of_packets), UVM_LOW)
    endtask
endclass