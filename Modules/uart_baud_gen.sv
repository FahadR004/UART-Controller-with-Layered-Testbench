//------------------------------------------------------------------------------
// Baud Rate Generator
// Produces a single-cycle-wide tick at 16x the configured baud rate.
//------------------------------------------------------------------------------
module uart_baud_gen #(
    parameter int CLK_FREQ_HZ = 50_000_000,
    parameter int BAUD_RATE   = 115_200
) (
    input  logic clk,
    input  logic rst_n,
    output logic tick_x16   // pulses once per (1/(16*BAUD_RATE)) seconds
);

localparam int DIVISOR = CLK_FREQ_HZ / (BAUD_RATE * 16);
// Sanity: DIVISOR should be >= 1. For 50MHz/115200 baud -> ~27.  (27.12673611111111)
logic [$clog2(DIVISOR):0] count;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count    <= '0;
        tick_x16 <= 1'b0;
    end else if (count == DIVISOR - 1) begin
        count    <= '0;
        tick_x16 <= 1'b1;
    end else begin
        count    <= count + 1'b1;
        tick_x16 <= 1'b0;
    end
end

endmodule

