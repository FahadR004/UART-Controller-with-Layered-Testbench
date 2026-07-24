//==============================================================================
// UART Scoreboard
// For each generated transaction, checks two independent things against it:
//   - TX path : did the DUT transmit tx_serial that decodes back to the same
//               data, with clean (non-corrupted) parity? (TX never injects
//               errors - only drive_rx does.)
//   - RX path : did the DUT correctly decode the bit-banged rx_serial frame,
//               and did its rx_parity_err flag match whether the driver
//               deliberately corrupted parity for this transaction?
//==============================================================================

class scoreboard #(parameter int DATA_BITS = 8);

mailbox #(uart_transaction #(DATA_BITS)) gen2scb;   // expected values from generator
mailbox #(uart_transaction #(DATA_BITS)) mon2scb_tx; // observed TX result
mailbox #(uart_transaction #(DATA_BITS)) mon2scb_rx; // observed RX result

int tx_pass_count = 0;
int tx_fail_count = 0;
int rx_pass_count = 0;
int rx_fail_count = 0;

function new(mailbox #(uart_transaction #(DATA_BITS)) gen2scb,
             mailbox #(uart_transaction #(DATA_BITS)) mon2scb_tx,
             mailbox #(uart_transaction #(DATA_BITS)) mon2scb_rx);
    this.gen2scb    = gen2scb;
    this.mon2scb_tx = mon2scb_tx;
    this.mon2scb_rx = mon2scb_rx;
endfunction

task run();
    uart_transaction #(DATA_BITS) expected;
    uart_transaction #(DATA_BITS) tx_result;
    uart_transaction #(DATA_BITS) rx_result;

    forever begin
        gen2scb.get(expected);

        // Both results correspond to the same generated transaction,
        // since the driver drives TX and RX concurrently and only moves
        // on to the next transaction once both have completed.
        fork
            mon2scb_tx.get(tx_result);
            mon2scb_rx.get(rx_result);
        join

        check_tx(expected, tx_result);
        check_rx(expected, rx_result);
    end
endtask

task automatic check_tx(uart_transaction #(DATA_BITS) expected,
                            uart_transaction #(DATA_BITS) actual);
    if (actual.data !== expected.data) begin
        $error("[Scoreboard][TX] DATA MISMATCH: expected=0x%0h observed=0x%0h",
                expected.data, actual.data);
        tx_fail_count++;
    end else if (actual.parity_err_detected) begin
        // TX never intentionally corrupts its own output - any parity
        // mismatch decoded off tx_serial indicates a real DUT/TX bug.
        $error("[Scoreboard][TX] Unexpected parity error decoded for data=0x%0h",
                expected.data);
        tx_fail_count++;
    end else begin
        $display("[Scoreboard][TX] PASS data=0x%0h", expected.data);
        tx_pass_count++;
    end
endtask

task automatic check_rx(uart_transaction #(DATA_BITS) expected,
                            uart_transaction #(DATA_BITS) actual);
    bit rx_ok = 1'b1;

    if (actual.data !== expected.data) begin
        $error("[Scoreboard][RX] DATA MISMATCH: expected=0x%0h observed=0x%0h",
                expected.data, actual.data);
        rx_ok = 1'b0;
    end

    if (actual.parity_err_detected !== expected.inject_parity_err) begin
        $error("[Scoreboard][RX] parity_err flag MISMATCH: expected=%0b observed=%0b (data=0x%0h)",
                expected.inject_parity_err, actual.parity_err_detected, expected.data);
        rx_ok = 1'b0;
    end

    if (rx_ok) begin
        $display("[Scoreboard][RX] PASS data=0x%0h inject_parity_err=%0b",
                    expected.data, expected.inject_parity_err);
        rx_pass_count++;
    end else begin
        rx_fail_count++;
    end
endtask

function void report();
    $display("--------------------------------------------------");
    $display("[Scoreboard] TX: %0d passed, %0d failed", tx_pass_count, tx_fail_count);
    $display("[Scoreboard] RX: %0d passed, %0d failed", rx_pass_count, rx_fail_count);
    $display("--------------------------------------------------");
endfunction

endclass