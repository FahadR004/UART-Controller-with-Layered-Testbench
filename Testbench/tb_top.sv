//==============================================================================
// UART Top-Level Testbench
// Instantiates the interface and the DUT (uart_top), connects them, generates
// the clock, and launches the test.
//==============================================================================

`include "../Modules/uart_top.sv"            // RTL: uart_pkg + uart_baud_gen/uart_tx/uart_rx/uart_top
`include "interface.sv"  // interface must exist before the TB package references it
`include "uart_tb_pkg.sv"     // all TB classes, bundled into one package

module uart_tb_top;

    import uart_tb_pkg::*;

    localparam int    DATA_BITS   = 8;
    localparam int    CLK_FREQ_HZ = 50_000_000;
    localparam int    BAUD_RATE   = 115_200;
    localparam string PARITY      = "EVEN";
    localparam int    STOP_BITS   = 1;

    //--------------------------------------------------------------------
    // Clock generation: period = 1/CLK_FREQ_HZ. At 50MHz -> 20ns period,
    // so toggle every 10ns.
    //--------------------------------------------------------------------
    bit clk = 1'b0;
    always #10 clk = ~clk;

    //--------------------------------------------------------------------
    // Interface instance
    //--------------------------------------------------------------------
    uart_interface #(.DATA_BITS(DATA_BITS)) intf (.clk(clk));

    //--------------------------------------------------------------------
    // DUT instance - individual signal connections (uart_top uses plain
    // ports, not an interface port, so each signal is wired explicitly)
    //--------------------------------------------------------------------
    uart_top #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE   (BAUD_RATE),
        .DATA_BITS   (DATA_BITS),
        .PARITY      (PARITY),
        .STOP_BITS   (STOP_BITS)
    ) dut (
        .clk           (clk),
        .rst_n         (intf.rst_n),
        .tx_start      (intf.tx_start),
        .tx_data       (intf.tx_data),
        .tx_busy       (intf.tx_busy),
        .tx_done       (intf.tx_done),
        .tx_serial     (intf.tx_serial),
        .rx_serial     (intf.rx_serial),
        .rx_data       (intf.rx_data),
        .rx_valid      (intf.rx_valid),
        .rx_parity_err (intf.rx_parity_err),
        .rx_frame_err  (intf.rx_frame_err)
    );

    //--------------------------------------------------------------------
    // Launch the test
    //--------------------------------------------------------------------
    initial begin
        test #(
            .DATA_BITS   (DATA_BITS),
            .CLK_FREQ_HZ (CLK_FREQ_HZ),
            .BAUD_RATE   (BAUD_RATE),
            .PARITY      (PARITY),
            .STOP_BITS   (STOP_BITS)
        ) t;

        t = new(intf); // implicit conversion: interface instance -> virtual interface.TB
        t.run();

        $display("[TB] Test complete");
        $finish;
    end

endmodule