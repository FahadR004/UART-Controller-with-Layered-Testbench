//==============================================================================
// UART Environment
// Owns and connects every component: creates all mailboxes, instantiates
// generator/driver/monitor/scoreboard, and sequences a full test run.
//==============================================================================

class environment #(
    parameter int    DATA_BITS   = 8,
    parameter int    CLK_FREQ_HZ = 50_000_000,
    parameter int    BAUD_RATE   = 115_200,
    parameter string PARITY      = "NONE",
    parameter int    STOP_BITS   = 1
);

virtual uart_interface.TB uart_intrf;

generator  #(DATA_BITS) gen;
driver     #(DATA_BITS, CLK_FREQ_HZ, BAUD_RATE, PARITY, STOP_BITS) drv;
monitor    #(DATA_BITS, CLK_FREQ_HZ, BAUD_RATE, PARITY, STOP_BITS) mon;
scoreboard #(DATA_BITS) scb;

mailbox #(uart_transaction #(DATA_BITS)) genToDrv;
mailbox #(uart_transaction #(DATA_BITS)) gen2scb;
mailbox #(uart_transaction #(DATA_BITS)) mon2scb_tx;
mailbox #(uart_transaction #(DATA_BITS)) mon2scb_rx;

function new(virtual uart_interface.TB uart_intrf);
    this.uart_intrf = uart_intrf;

    genToDrv   = new();
    gen2scb    = new();
    mon2scb_tx = new();
    mon2scb_rx = new();

    gen = new(genToDrv, gen2scb);
    drv = new(uart_intrf, genToDrv);
    mon = new(uart_intrf, mon2scb_tx, mon2scb_rx);
    scb = new(gen2scb, mon2scb_tx, mon2scb_rx);
endfunction

task run();
    drv.reset();

    // driver/monitor/scoreboard run forever - start them in the
    // background so gen_values() below can be called as a normal
    // blocking task that returns once it's produced everything.
    fork
        drv.run();
        mon.run();
        scb.run();
    join_none

    gen.gen_values();

    // let the last few in-flight transactions finish draining through
    // driver -> monitor -> scoreboard before reporting final results
    wait ((scb.tx_pass_count + scb.tx_fail_count) == gen.num_transactions);

    scb.report();
endtask

endclass