module simple_interconnect (

    input  logic        clk,
    input  logic        rst,

    // CPU interface
    input  logic        req_valid,
    input  logic        req_write,
    input  logic [7:0]  req_addr,
    input  logic [7:0]  req_wdata,

    output logic        resp_ready,
    output logic [7:0]  resp_rdata
);

// Cache ↔ Memory wires
//already defined in cache module, just connect cache to memory using simple_interconnect
logic        mem_req_valid;
logic        mem_req_write;
logic [7:0]  mem_req_addr;
logic [7:0]  mem_req_wdata;

logic        mem_resp_ready;
logic [7:0]  mem_resp_rdata;



cache_controller cache_inst (

    .clk(clk),
    .rst(rst),

    // CPU side(cpu to cache)
    .req_valid(req_valid && sel_mem),
    .req_write(req_write),
    .req_addr(req_addr),
    .req_wdata(req_wdata),

    // response from cache
    .resp_ready(mem_ready),
    .resp_rdata(mem_rdata),

    // Memory side(cache to mem)
    .mem_req_valid(mem_req_valid),
    .mem_req_write(mem_req_write),
    .mem_req_addr(mem_req_addr),
    .mem_req_wdata(mem_req_wdata),

    .mem_resp_ready(mem_resp_ready),
    .mem_resp_rdata(mem_resp_rdata)
);


//MEMORY INSTANCE: hardware block
simple_memory mem_inst (

    .clk(clk),
    .rst(rst),

    .req_valid(mem_req_valid),
    .req_write(mem_req_write),
    .req_addr(mem_req_addr),
    .req_wdata(mem_req_wdata),

    .resp_ready(mem_resp_ready),
    .resp_rdata(mem_resp_rdata)
);



    // =============================
    // Address decode
    // =============================

    logic sel_mem;
    logic sel_timer;

    assign sel_mem   = (req_addr < 8'h80); //0x00 to 0x7F
    
    assign sel_timer = (req_addr >= 8'h80) && (req_addr < 8'h90);
    //0x80 to 0x8F (small peripheral with a few registers)
    
    // =============================
    // Convert global → local
    // =============================

    logic [7:0] timer_addr;
    assign timer_addr = req_addr - 8'h80;
    //local addressing for timer
    //requested adress- base adress 0x80
    //memory starts at base 0x00, hence offset not reqd nd global addressing can be used

    // =============================
    // Memory response wires
    // =============================

    logic mem_ready;
    logic [7:0] mem_rdata;

    // =============================
    // Timer response wires
    // =============================

    logic tim_ready;
    logic [7:0] tim_rdata;

 

    // =============================
    // Timer instance
    // =============================

    timer_pwm tim_inst (

        .clk(clk),
        .rst(rst),

        .req_valid(req_valid && sel_timer),
        .req_write(req_write),
        .req_addr(timer_addr),   // LOCAL address
        .req_wdata(req_wdata),

        .resp_ready(tim_ready),
        .resp_rdata(tim_rdata),

        .pwm_out() //unconnected as of now
    );

    // =============================
    // Response MUX
    // =============================

    always_comb begin

        resp_ready = 0;
        resp_rdata = 8'h00;

        if (sel_mem) begin
            resp_ready = mem_ready;
            resp_rdata = mem_rdata;
        end
        else if (sel_timer) begin
            resp_ready = tim_ready;
            resp_rdata = tim_rdata;
        end

    end

endmodule