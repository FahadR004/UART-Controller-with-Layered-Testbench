//==============================================================================
// UART (Universal Asynchronous Receiver/Transmitter)
// Parameterized: clock frequency, baud rate, data bits, parity, stop bits
// Oversampling ratio: 16x baud rate for the receiver
//==============================================================================

//------------------------------------------------------------------------------
// Shared package: single source of truth for parity calculation, used by
// both TX (to generate the parity bit) and RX (to check the received one).
//------------------------------------------------------------------------------
package uart_pkg;
 
    // width: number of valid data bits in `data` (i.e. DATA_BITS)
    // parity_mode: "NONE", "EVEN", or "ODD"
    function automatic logic calc_parity(
        input logic [31:0] data,
        input int          width,
        input string       parity_mode
    );
        logic [31:0] mask;
        logic [31:0] masked_data;
        logic        p;
 
        // Build a `width`-bit mask at runtime (part-selects can't use a
        // variable width, even with +:/-: operators, so we mask instead).
        mask        = (32'd1 << width) - 32'd1;
        masked_data = data & mask;
 
        unique case (parity_mode)
            "EVEN":   p = ^masked_data;
            "ODD":    p = ~(^masked_data);
            default:  p = 1'b0; // "NONE" - unused, defined tie-off value
        endcase
        return p;
    endfunction
 
endpackage
 