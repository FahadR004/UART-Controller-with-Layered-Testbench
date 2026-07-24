class generator #(
    parameter DATA_BITS = 8
);

uart_transaction #(DATA_BITS) tr;
mailbox #(uart_transaction #(DATA_BITS)) genToDrv;
mailbox #(uart_transaction #(DATA_BITS))    gen2scb;

function new(mailbox #(uart_transaction #(DATA_BITS)) genToDrv,
                mailbox #(uart_transaction #(DATA_BITS)) gen2scb);
    this.genToDrv = genToDrv;
    this.gen2scb  = gen2scb;
endfunction

int num_transactions = 20;

task gen_values();
    repeat (num_transactions) begin
        tr = new(); // Initialization
        // randomize() is inherited by all classes
        //if (!tr.randomize())
        //    $error("Randomization failed");
 	tr.data = $urandom_range(0, (2**DATA_BITS)-1);
        tr.inject_parity_err = ($urandom_range(1, 100) <= 10); // ~10% weighted, mirrors the dist
        genToDrv.put(tr); // Put the transaction class in the mailbox
        gen2scb.put(tr.copy()); // independent copy - scoreboard's "expected" value 
        // must never change after the driver consumes tr
        tr.display("[Generator] TXN");
    end
endtask 

endclass 