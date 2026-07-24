
//------------------------------------------------------------------------------
// UART Transmitter
// Shifts out: start bit -> data bits (LSB first) -> optional parity -> stop bit(s)
//------------------------------------------------------------------------------
module uart_tx #(
    parameter int    DATA_BITS = 8,
    parameter string PARITY    = "NONE",   // "NONE", "EVEN", "ODD"
    parameter int    STOP_BITS = 1         // 1 or 2
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  baud_tick_x16,   // 16x baud tick from generator
    input  logic                  tx_start,        // pulse to begin a new frame
    input  logic [DATA_BITS-1:0]  tx_data,
    output logic                  tx_busy,
    output logic                  tx_done,         // 1-cycle pulse when frame complete
    output logic                  tx_serial
);

import uart_pkg::calc_parity;

typedef enum logic [2:0] {
    IDLE, START, DATA, PARITY_ST, STOP
} tx_state_e;

tx_state_e               state;
logic [3:0]              tick_cnt;     // counts 0..15 within a bit period
logic [$clog2(DATA_BITS)-1:0] bit_idx;
logic [DATA_BITS-1:0]    shift_reg;
logic                    parity_bit;
logic [1:0]              stop_cnt;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= IDLE;
        tick_cnt   <= '0;
        bit_idx    <= '0;
        shift_reg  <= '0;
        parity_bit <= 1'b0;
        stop_cnt   <= '0;
        tx_serial  <= 1'b1;   // idle line is high
        tx_busy    <= 1'b0;
        tx_done    <= 1'b0;
    end else begin
        tx_done <= 1'b0; // default, pulsed only on completion

        case (state)
            IDLE: begin
                tx_serial <= 1'b1;
                tx_busy   <= 1'b0;
                if (tx_start) begin
                    shift_reg  <= tx_data;
                    parity_bit <= calc_parity(tx_data, DATA_BITS, PARITY);
                    bit_idx    <= '0;
                    tick_cnt   <= '0;
                    stop_cnt   <= '0;
                    tx_busy    <= 1'b1;
                    state      <= START;
                end
            end

            START: begin
                tx_serial <= 1'b0; // start bit
                if (baud_tick_x16) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt <= '0;
                        state    <= DATA;
                    end else
                        tick_cnt <= tick_cnt + 1'b1;
                end
            end

            DATA: begin
                tx_serial <= shift_reg[0];
                if (baud_tick_x16) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt  <= '0;
                        shift_reg <= shift_reg >> 1;
                        if (bit_idx == DATA_BITS - 1) begin
                            bit_idx <= '0;
                            state   <= (PARITY != "NONE") ? PARITY_ST : STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else
                        tick_cnt <= tick_cnt + 1'b1;
                end
            end

            PARITY_ST: begin
                tx_serial <= parity_bit;
                if (baud_tick_x16) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt <= '0;
                        state    <= STOP;
                    end else
                        tick_cnt <= tick_cnt + 1'b1;
                end
            end

            STOP: begin
                tx_serial <= 1'b1; // stop bit(s) are high
                if (baud_tick_x16) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt <= '0;
                        if (stop_cnt == STOP_BITS - 1) begin
                            stop_cnt <= '0;
                            tx_busy  <= 1'b0;
                            tx_done  <= 1'b1;
                            state    <= IDLE;
                        end else begin
                            stop_cnt <= stop_cnt + 1'b1;
                        end
                    end else
                        tick_cnt <= tick_cnt + 1'b1;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
