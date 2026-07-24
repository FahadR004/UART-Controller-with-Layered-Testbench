

//------------------------------------------------------------------------------
// UART Receiver
// Oversamples the line at 16x baud rate, detects start edge, confirms it at
// mid-bit, then samples each subsequent bit at its midpoint.
//------------------------------------------------------------------------------
module uart_rx #(
    parameter int    DATA_BITS = 8,
    parameter string PARITY    = "NONE",   // "NONE", "EVEN", "ODD"
    parameter int    STOP_BITS = 1
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  baud_tick_x16,
    input  logic                  rx_serial,
    output logic [DATA_BITS-1:0]  rx_data,
    output logic                  rx_valid,       // 1-cycle pulse: new byte ready
    output logic                  rx_parity_err,  // valid on same cycle as rx_valid
    output logic                  rx_frame_err    // stop bit not seen high
);

import uart_pkg::calc_parity;

typedef enum logic [2:0] {
    IDLE, START_CONFIRM, DATA, PARITY_ST, STOP
} rx_state_e;

rx_state_e                     state;
logic [3:0]                    tick_cnt;
logic [$clog2(DATA_BITS)-1:0]  bit_idx;
logic [DATA_BITS-1:0]          shift_reg;
logic                          rx_sync0, rx_sync1, rx_line; // 2-FF synchronizer
logic                          parity_calc;

// Synchronize the asynchronous serial input into our clock domain
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_sync0 <= 1'b1;
        rx_sync1 <= 1'b1;
    end else begin
        rx_sync0 <= rx_serial;
        rx_sync1 <= rx_sync0;
    end
end
assign rx_line = rx_sync1;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state         <= IDLE;
        tick_cnt      <= '0;
        bit_idx       <= '0;
        shift_reg     <= '0;
        rx_data       <= '0;
        rx_valid      <= 1'b0;
        rx_parity_err <= 1'b0;
        rx_frame_err  <= 1'b0;
    end else begin
        rx_valid <= 1'b0; // default, pulsed only when a byte completes

        case (state)
            IDLE: begin
                tick_cnt <= '0;
                if (!rx_line) begin // falling edge -> possible start bit
                    state <= START_CONFIRM;
                end
            end

            // Wait to the middle of the start bit (8 x16-ticks in) and
            // re-check the line is still low, to reject glitches.
            START_CONFIRM: begin
                if (baud_tick_x16) begin
                    if (tick_cnt == 4'd7) begin
                        if (!rx_line) begin
                            tick_cnt <= '0;
                            bit_idx  <= '0;
                            state    <= DATA;
                        end else begin
                            state <= IDLE; // false start, back to idle
                        end
                    end else
                        tick_cnt <= tick_cnt + 1'b1;
                end
            end

            DATA: begin
                if (baud_tick_x16) begin // Since, we came to data state after 7 ticks (meaning half of the start bit), counting to full 16 ticks lands us at the middle of the next bit
                    if (tick_cnt == 4'd15) begin
                        tick_cnt  <= '0;
                        shift_reg <= {rx_line, shift_reg[DATA_BITS-1:1]}; // Discarding 0th bit each time and appending with the new data
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
                if (baud_tick_x16) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt      <= '0;
                        parity_calc    = calc_parity(shift_reg, DATA_BITS, PARITY);
                        rx_parity_err <= (parity_calc != rx_line); 
                        state <= STOP;
                    end else
                        tick_cnt <= tick_cnt + 1'b1;
                end
            end

            STOP: begin
                if (baud_tick_x16) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt     <= '0;
                        rx_frame_err <= ~rx_line; // stop bit should be high
                        rx_data      <= shift_reg;
                        rx_valid     <= 1'b1;
                        state        <= IDLE;
                    end else
                        tick_cnt <= tick_cnt + 1'b1;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule

