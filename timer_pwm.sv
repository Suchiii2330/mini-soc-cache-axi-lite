module timer_pwm (

    input  logic        clk,
    input  logic        rst,

    // Memory-mapped interface
    input  logic        req_valid,
    input  logic        req_write,
    input  logic [7:0]  req_addr,
    input  logic [7:0]  req_wdata,

    output logic        resp_ready,
    output logic [7:0]  resp_rdata,

    // Output signal
    output logic        pwm_out
);

    // =============================
    // Registers
    // =============================

    logic [7:0] period;
    logic [7:0] duty;
    logic       enable;

    logic [7:0] counter;

    // =============================
    // Register Read/Write
    // =============================

    always_ff @(posedge clk) begin
        if (rst) begin
            period <= 0;
            duty   <= 0;
            enable <= 0;
            resp_ready <= 0;
        end else begin
            resp_ready <= 0;

            if (req_valid) begin
                resp_ready <= 1;

                if (req_write) begin
                    case (req_addr)
                        8'h00: period <= req_wdata;
                        8'h04: duty   <= req_wdata;
                        8'h08: enable <= req_wdata[0];
                    endcase
                end else begin
                    case (req_addr)
                        8'h00: resp_rdata <= period;
                        8'h04: resp_rdata <= duty;
                        8'h08: resp_rdata <= {7'b0, enable};
                        default: resp_rdata <= 8'h00;
                    endcase
                end
            end
        end
    end

    // =============================
    // Timer Logic
    // =============================

    always_ff @(posedge clk) begin
        if (rst) begin
            counter <= 0;
            pwm_out <= 0;
        end else if (enable) begin

            if (counter >= period)
                counter <= 0;
            else
                counter <= counter + 1;

            pwm_out <= (counter < duty);

        end else begin
            counter <= 0;
            pwm_out <= 0;
        end
    end

endmodule