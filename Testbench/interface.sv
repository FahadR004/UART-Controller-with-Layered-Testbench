interface uart_interface #(
    parameter int DATA_BITS = 8
) (
    input bit clk
);

logic rst_n;

logic tx_start;
logic [DATA_BITS-1:0]  tx_data;
logic tx_busy;
logic tx_done;
logic tx_serial;

logic rx_serial;
logic [DATA_BITS-1:0]  rx_data;
logic rx_valid;
logic rx_parity_err;
logic rx_frame_err;

// This is for the testbench
// We need to place a break between the driver writing the signals to the interface (bundle of wires) and the DUT reading the signals, so there is no race condition
// DUT will safely read the old tx_start before it reads the rst_n
// tx_busy etc are read safely and correctly before the clock edge and new update by the DUT 
clocking uart_cb @(posedge clk);
    default input #1step output #1; // every signal gets this
    output rst_n, tx_start, tx_data, rx_serial;
    input  tx_busy, tx_done, tx_serial, rx_data, rx_valid,
            rx_parity_err, rx_frame_err;
endclocking

// This is for the DUT itself. Makes sense that it takes tx_start etc as input and tx_busy as output. Same as the top file
modport DUT (
    input  rst_n, tx_start, tx_data, rx_serial,
    output tx_busy, tx_done, tx_serial, rx_data, rx_valid,
            rx_parity_err, rx_frame_err
);

modport TB (
    clocking uart_cb
);

endinterface