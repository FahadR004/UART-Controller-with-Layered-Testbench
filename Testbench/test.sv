//==============================================================================
// UART Test
// Thin wrapper around the environment - this is the layer a specific test
// scenario would customize (e.g. override gen.num_transactions, or later
// add constraint overrides for directed error-injection tests).
//==============================================================================

class test #(
    parameter int    DATA_BITS   = 8,
    parameter int    CLK_FREQ_HZ = 50_000_000,
    parameter int    BAUD_RATE   = 115_200,
    parameter string PARITY      = "NONE",
    parameter int    STOP_BITS   = 1
);

environment #(DATA_BITS, CLK_FREQ_HZ, BAUD_RATE, PARITY, STOP_BITS) env;

function new(virtual uart_interface.TB uart_intrf);
    env = new(uart_intrf);
endfunction

task run();
    // Example of how a specific test would customize behavior:
    // env.gen.num_transactions = 100;
    env.run();
endtask

endclass