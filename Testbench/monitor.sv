//==============================================================================
// UART Monitor
// Two independent, concurrently-running watchers:
//   - monitor_tx : passively decodes the tx_serial waveform bit-by-bit
//                  (start bit -> data -> parity -> stop) to reconstruct the
//                  byte the DUT transmitted. Needed because tx_serial is a
//                  raw serial line with no ready-made "byte" signal.
//   - monitor_rx : simply waits for rx_valid and captures the DUT's own
//                  already-decoded rx_data/error flags directly.
// Each pushes its result to a separate mailbox, since a TX observation and
// an RX observation are checked against different expected values.
//==============================================================================

class monitor #(
    parameter int    DATA_BITS   = 8,
    parameter int    CLK_FREQ_HZ = 50_000_000,
    parameter int    BAUD_RATE   = 115_200,
    parameter string PARITY      = "NONE",
    parameter int    STOP_BITS   = 1
);

virtual uart_interface.TB uart_intrf;

mailbox #(uart_transaction #(DATA_BITS)) mon2scb_tx;
mailbox #(uart_transaction #(DATA_BITS)) mon2scb_rx;

localparam int CYCLES_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

function new(virtual uart_interface.TB uart_intrf,
                mailbox #(uart_transaction #(DATA_BITS)) mon2scb_tx,
                mailbox #(uart_transaction #(DATA_BITS)) mon2scb_rx);
    this.uart_intrf = uart_intrf;
    this.mon2scb_tx = mon2scb_tx;
    this.mon2scb_rx = mon2scb_rx;
endfunction

// ---- Decode tx_serial by watching for edges and sampling mid-bit ------
task automatic monitor_tx();
    uart_transaction #(DATA_BITS) tr;
    bit                           prev_line = 1'b1;
    bit                           cur_line;
    bit [DATA_BITS-1:0]           shift_reg;
    bit                           parity_bit;

    forever begin
        @(uart_intrf.uart_cb);
        cur_line = uart_intrf.uart_cb.tx_serial;

        // Falling edge on an idle-high line = start bit beginning
        if (prev_line == 1'b1 && cur_line == 1'b0) begin
            // Move to the middle of the start bit
            repeat (CYCLES_PER_BIT / 2) @(uart_intrf.uart_cb);

            // Sample each data bit at the middle of its bit period, LSB first
            for (int i = 0; i < DATA_BITS; i++) begin
                repeat (CYCLES_PER_BIT) @(uart_intrf.uart_cb);
                shift_reg[i] = uart_intrf.uart_cb.tx_serial;
            end

            if (PARITY != "NONE") begin
                repeat (CYCLES_PER_BIT) @(uart_intrf.uart_cb);
                parity_bit = uart_intrf.uart_cb.tx_serial;
            end

            tr = new();
            tr.data                = shift_reg;
            tr.valid               = 1'b1;
            tr.parity_err_detected = (PARITY != "NONE") &&
                                        (parity_bit != calc_parity(shift_reg, DATA_BITS, PARITY));

            tr.display("Monitor TX");
            mon2scb_tx.put(tr);

            // resync so we don't re-trigger inside the frame we just read
            cur_line = uart_intrf.uart_cb.tx_serial;
        end

        prev_line = cur_line;
    end
endtask

// ---- Capture the DUT's own already-decoded RX result -------------------
task automatic monitor_rx();
    uart_transaction #(DATA_BITS) tr;
    forever begin
        @(uart_intrf.uart_cb);
        if (uart_intrf.uart_cb.rx_valid) begin
            tr = new();
            tr.data                = uart_intrf.uart_cb.rx_data;
            tr.valid               = 1'b1;
            tr.parity_err_detected = uart_intrf.uart_cb.rx_parity_err;
            tr.frame_err_detected  = uart_intrf.uart_cb.rx_frame_err;

            tr.display("Monitor RX");
            mon2scb_rx.put(tr);
        end
    end
endtask

task run();
    fork
        monitor_tx();
        monitor_rx();
    join
endtask

endclass