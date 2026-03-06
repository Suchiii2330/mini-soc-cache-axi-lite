module direct_mapped_cache (

    input  logic        clk,
    input  logic        rst,

    input  logic        req_valid,
    input  logic        req_write,
    input  logic [7:0]  req_addr,
    input  logic [7:0]  req_wdata,

    output logic        hit,
    output logic [7:0]  resp_rdata
);

    logic [1:0] offset = req_addr[1:0];
    logic [1:0] index  = req_addr[3:2];
    logic [3:0] tag    = req_addr[7:4];

    logic        valid [0:3];
    logic        dirty [0:3];
    logic [3:0]  tag_array [0:3];
    logic [31:0] data_array[0:3];

    integer i;

    // Reset
    always_ff @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 4; i++) begin
                valid[i] <= 0;
                dirty[i] <= 0;
                tag_array[i] <= 0;
                data_array[i] <= 0;
            end
        end
    end

    // Hit logic
    always_comb begin
        hit = 0;
        resp_rdata = 8'h00;

        if (req_valid) begin
            if ( valid[index] && (tag_array[index] == tag) ) begin
                hit = 1;

                case (offset)
                    2'b00: resp_rdata = data_array[index][7:0];
                    2'b01: resp_rdata = data_array[index][15:8];
                    2'b10: resp_rdata = data_array[index][23:16];
                    2'b11: resp_rdata = data_array[index][31:24];
                endcase
            end
        end
    end

endmodule