module simple_memory #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8,
    parameter LATENCY    = 2
)(
    input  logic                     clk,
    input  logic                     rst,

    // Request (cache to memory)
    input  logic                     req_valid,
    input  logic                     req_write,
    input  logic [ADDR_WIDTH-1:0]    req_addr,
    input  logic [DATA_WIDTH-1:0]    req_wdata,

    // Response (memory to cache)
    output logic                     resp_ready,
    output logic [DATA_WIDTH-1:0]    resp_rdata
);

    localparam MEM_SIZE = 1 << ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] mem [0:MEM_SIZE-1];

    logic [$clog2(LATENCY+1)-1:0] delay_cnt;
    logic busy;

    logic latched_write;
    logic [ADDR_WIDTH-1:0] latched_addr;
    logic [DATA_WIDTH-1:0] latched_wdata;

    integer i;

    // Memory initialization (for simulation clarity)
    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1)
            mem[i] = i;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            busy       <= 0;
            resp_ready <= 0;
            delay_cnt  <= 0;
        end 
        else begin
            resp_ready <= 0;

            if (req_valid && !busy) begin
                busy          <= 1;
                delay_cnt     <= LATENCY;

                latched_write <= req_write;
                latched_addr  <= req_addr;
                latched_wdata <= req_wdata;
            end

            else if (busy) begin
                if (delay_cnt > 0) begin
                    delay_cnt <= delay_cnt - 1;
                end 
                else begin
                    if (latched_write)
                        mem[latched_addr] <= latched_wdata;
                    else
                        resp_rdata <= mem[latched_addr];

                    resp_ready <= 1;
                    busy <= 0;
                end
            end
        end
    end

endmodule