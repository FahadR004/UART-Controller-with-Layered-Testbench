
//------------------------------------------------------------------------------
// Top-level UART: wraps baud generator + TX + RX
//------------------------------------------------------------------------------
module uart_top #(
    parameter int    CLK_FREQ_HZ = 50_000_000,
    parameter int    BAUD_RATE   = 115_200,
    parameter int    DATA_BITS   = 8,
    parameter string PARITY      = "NONE",
    parameter int    STOP_BITS   = 1
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // TX interface
    input  logic                  tx_start,
    input  logic [DATA_BITS-1:0]  tx_data,
    output logic                  tx_busy,
    output logic                  tx_done,
    output logic                  tx_serial,

    // RX interface
    input  logic                  rx_serial,
    output logic [DATA_BITS-1:0]  rx_data,
    output logic                  rx_valid,
    output logic                  rx_parity_err,
    output logic                  rx_frame_err
);

logic baud_tick_x16;

uart_baud_gen #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .BAUD_RATE   (BAUD_RATE)
) u_baud_gen (
    .clk      (clk),
    .rst_n    (rst_n),
    .tick_x16 (baud_tick_x16)
);

// In an actual UART link, there are two chips/boards that are communicating. We're simulating one chip in that communication. 
// What this means is that the data transmitted by the transmitter is NOT recieved by the reciever. But, instead both those lines are independent. And you would have to simulate data driven to the reciever end instead of relying on the transmitter.

uart_tx #(
    .DATA_BITS (DATA_BITS),
    .PARITY    (PARITY),
    .STOP_BITS (STOP_BITS)
) u_tx (
    .clk           (clk),
    .rst_n         (rst_n),
    .baud_tick_x16 (baud_tick_x16),
    .tx_start      (tx_start),
    .tx_data       (tx_data),
    .tx_busy       (tx_busy),
    .tx_done       (tx_done),
    .tx_serial     (tx_serial)
);

uart_rx #(
    .DATA_BITS (DATA_BITS),
    .PARITY    (PARITY),
    .STOP_BITS (STOP_BITS)
) u_rx (
    .clk           (clk),
    .rst_n         (rst_n),
    .baud_tick_x16 (baud_tick_x16),
    .rx_serial     (rx_serial),
    .rx_data       (rx_data),
    .rx_valid      (rx_valid),
    .rx_parity_err (rx_parity_err),
    .rx_frame_err  (rx_frame_err)
);

endmodule