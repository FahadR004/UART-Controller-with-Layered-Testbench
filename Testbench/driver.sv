class driver #(
    parameter int    DATA_BITS   = 8,
    parameter int    CLK_FREQ_HZ = 50_000_000,
    parameter int    BAUD_RATE   = 115_200,
    parameter string PARITY      = "NONE",
    parameter int    STOP_BITS   = 1
);

 
virtual uart_interface.TB uart_intrf;
mailbox #(uart_transaction #(DATA_BITS)) genToDrv;

// It's not divided by 16 because the transmitter won't oversample it's input. That is the reciever's job. The transmitter will hold one bit on the line for (50_000_000/115200 = approx. 434) cycles
localparam int CYCLES_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

function new(virtual uart_interface.TB uart_intrf, mailbox #(uart_transaction #(DATA_BITS)) genToDrv);
    this.uart_intrf = uart_intrf;
    this.genToDrv   = genToDrv;
endfunction

// Hold a bit on the line for 434 cycles
task automatic send_bit(bit b);
    uart_intrf.uart_cb.rx_serial <= b;
    repeat (CYCLES_PER_BIT) @(uart_intrf.uart_cb);
endtask

task reset();
    uart_intrf.uart_cb.rst_n <= 1'b0;  
    uart_intrf.uart_cb.tx_start <= 1'b0;
    uart_intrf.uart_cb.tx_data <= '0;
    uart_intrf.uart_cb.rx_serial <= 1'b1;  // idle line is high
    repeat (2) @(uart_intrf.uart_cb);
    uart_intrf.uart_cb.rst_n <= 1'b1;
    @(uart_intrf.uart_cb);
    $display("[Driver] Reset finished");
endtask

// Transmitter
task automatic drive_tx(uart_transaction #(DATA_BITS) t);
    @(uart_intrf.uart_cb);
    uart_intrf.uart_cb.tx_data <= t.data;
    uart_intrf.uart_cb.tx_start <= 1'b1;
    @(uart_intrf.uart_cb);
    uart_intrf.uart_cb.tx_start <= 1'b0;
    // wait until the transmitter reports the frame is complete
    do
        @(uart_intrf.uart_cb);
    while (!uart_intrf.uart_cb.tx_done);
endtask

// Reciever side
task automatic drive_rx(uart_transaction #(DATA_BITS) t);
    bit parity_bit;

    parity_bit = calc_parity(t.data, DATA_BITS, PARITY);
    if (t.inject_parity_err)
        parity_bit = ~parity_bit; // deliberately corrupt, for negative testing

    send_bit(1'b0); // start bit

    for (int i = 0; i < DATA_BITS; i++)
        send_bit(t.data[i]); // LSB first

    if (PARITY != "NONE")
        send_bit(parity_bit);

    repeat (STOP_BITS)
        send_bit(1'b1); // stop bit(s)
endtask

task run();
    uart_transaction #(DATA_BITS) tr;
    forever begin
        genToDrv.get(tr); // Get the transaction object placed in the mailbox by generator
        fork
            drive_tx(tr); // Drive values to the transmitter 
            drive_rx(tr); // Drive values to the reciever
        join
        tr.display("Driver");
    end
endtask
endclass