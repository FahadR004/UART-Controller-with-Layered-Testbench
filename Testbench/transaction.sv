class uart_transaction #(
    parameter int DATA_BITS = 8
);

rand bit [DATA_BITS-1:0] data;

// Tells the driver to intentionally corrupt the parity bit it sends,
// for negative testing of the RX's error-detection path.
rand bit inject_parity_err;

// Errors are rare and most transactions are clean.
constraint c_error_injection_rare {
    inject_parity_err dist { 1'b0 := 90, 1'b1 := 10 };
}

// Result fields
// Left at default by the generator/driver, 
// Filled in by the monitor once it reconstructs what actually happened on the
// interface (either the byte TX put out, or the byte RX captured).
bit valid;                // monitor saw a complete, well-formed frame
bit parity_err_detected;  // mirrors rx_parity_err at frame completion
bit frame_err_detected;   // mirrors rx_frame_err at frame completion

// Deep copy — used when handing a transaction across queues/mailboxes
// where you don't want two handles pointing at the same object.
function uart_transaction copy();
    uart_transaction #(DATA_BITS) t = new();
    t.data                = this.data;
    t.inject_parity_err   = this.inject_parity_err;
    t.valid               = this.valid;
    t.parity_err_detected = this.parity_err_detected;
    t.frame_err_detected  = this.frame_err_detected;
    return t;
endfunction

// Scoreboard comparison — what actually defines a "match" between
// what was sent and what was received.
function bit compare(uart_transaction #(DATA_BITS) rhs);
    return (this.data == rhs.data);
endfunction

function void display(string tag = "TXN");
    $display("[%0t] %s : data=0x%0h inject_parity_err=%0b valid=%0b parity_err_detected=%0b frame_err_detected=%0b",
                $time, tag, data, inject_parity_err, valid, parity_err_detected, frame_err_detected);
endfunction

endclass