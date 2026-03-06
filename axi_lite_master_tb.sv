module axi_lite_master_tb();

    // =============================
    // Clock + Reset
    // =============================

    logic ACLK;
    logic ARESETn;

    initial ACLK = 0;
    always #5 ACLK = ~ACLK;   // 100 MHz clock

    // =============================
    // AXI signals
    // =============================

    logic [7:0] AWADDR;
    logic       AWVALID;
    logic       AWREADY;

    logic [7:0] WDATA;
    logic       WSTRB;
    logic       WVALID;
    logic       WREADY;

    logic [1:0] BRESP;
    logic       BVALID;
    logic       BREADY;

    logic [7:0] ARADDR;
    logic       ARVALID;
    logic       ARREADY;

    logic [7:0] RDATA;
    logic [1:0] RRESP;
    logic       RVALID;
    logic       RREADY;


    // ===== Internal bus wires =====

    logic        req_valid;
    logic        req_write;
    logic [7:0]  req_addr;
    logic [7:0]  req_wdata;

    logic        resp_ready;
    logic [7:0]  resp_rdata;


    // =============================
    // DUT (your slave)- instantiation
    // =============================

    axi_lite_slave dut (

    .ACLK      (ACLK),
    .ARESETn   (ARESETn),

    // WRITE ADDRESS
    .AWADDR    (AWADDR),
    .AWVALID   (AWVALID),
    .AWREADY   (AWREADY),

    // WRITE DATA
    .WDATA     (WDATA),
    .WSTRB     (WSTRB),
    .WVALID    (WVALID),
    .WREADY    (WREADY),

    // WRITE RESPONSE
    .BRESP     (BRESP),
    .BVALID    (BVALID),
    .BREADY    (BREADY),

    // READ ADDRESS
    .ARADDR    (ARADDR),
    .ARVALID   (ARVALID),
    .ARREADY   (ARREADY),

    // READ DATA
    .RDATA     (RDATA),
    .RRESP     (RRESP),
    .RVALID    (RVALID),
    .RREADY    (RREADY),

    // ===== Internal bus =====
    .req_valid (req_valid),
    .req_write (req_write),
    .req_addr  (req_addr),
    .req_wdata (req_wdata),

    .resp_ready(resp_ready),
    .resp_rdata(resp_rdata)
);
    
    simple_interconnect interconnect_inst (
    .clk(ACLK),
    .rst(!ARESETn),

    .req_valid(req_valid),
    .req_write(req_write),
    .req_addr(req_addr),
    .req_wdata(req_wdata),

    .resp_ready(resp_ready),
    .resp_rdata(resp_rdata)
);


    // ====================================================
    // AXI WRITE TASK
    // ====================================================

    task axi_write(input [7:0] addr, input [7:0] data);
    begin
        // Address phase
        AWADDR  = addr;
        AWVALID = 1;

        wait (AWVALID && AWREADY);

        @(posedge ACLK);
        AWVALID = 0;

        // Data phase
        WDATA  = data;
        WSTRB  = 1;
        WVALID = 1;

        wait (WVALID && WREADY);

        @(posedge ACLK);
        WVALID = 0;

        // Response phase
        BREADY = 1;
        wait (BVALID && BREADY);

        @(posedge ACLK);
        BREADY = 0;
    end
    endtask


    // ====================================================
    // AXI READ TASK
    // ====================================================

    task axi_read(input [7:0] addr);
    begin
        // Address phase
        ARADDR  = addr;
        ARVALID = 1;

        wait (ARVALID && ARREADY);

        @(posedge ACLK);
        ARVALID = 0;

        // Data phase
        RREADY = 1;
        wait (RVALID && RREADY);

        $display("READ addr=%h data=%h resp=%b",
                 addr, RDATA, RRESP);

        @(posedge ACLK);
        RREADY = 0;
    end
    endtask


    // ====================================================
    // TEST SEQUENCE
    // ====================================================

    initial begin

        // Initialize signals
        AWVALID = 0;
        WVALID  = 0;
        BREADY  = 0;
        ARVALID = 0;
        RREADY  = 0;
        WSTRB   = 0;

        // avoid XX signals in waveform
        AWADDR = 0;
        WDATA  = 0;
        ARADDR = 0;

        // Reset
        ARESETn = 0;
        repeat (5) @(posedge ACLK);
        ARESETn = 1;



// ====================================================
// TEST 1
// Intention:
// Verify basic memory access through cache.
//
// Expected:
// 1) First write to address 0x10 → CACHE MISS
// 2) Cache line refill from memory
// 3) Read from same address → CACHE HIT
//
// Waveform expectation:
// req_valid pulse
// mem_req_valid active during refill
// resp_ready returned after refill
// ====================================================

        axi_write(8'h10, 8'hAA); // cache miss + refill
        axi_read(8'h10);         // cache hit



// ====================================================
// TEST 2
// Intention:
// Verify timer peripheral region bypasses cache.
//
// Expected:
// Address 0x80 goes to TIMER peripheral.
//
// Waveform expectation:
// req_valid asserted
// mem_req_valid should NOT toggle
// timer should respond directly
// ====================================================

        axi_write(8'h80, 8'h55);



// ====================================================
// TEST 3
// Intention:
// Verify reuse of the same cache line.
//
// Expected:
// First read → MISS and refill
// Next reads → HIT
//
// Waveform expectation:
// mem_req_valid only once
// subsequent accesses served from cache
// ====================================================

        axi_read(8'h11); // miss
        axi_read(8'h12); // hit
        axi_read(8'h13); // hit



// ====================================================
// TEST 4
// Intention:
// Verify cache writeback when new tag conflicts.
//
// Expected:
// Write 0x10 → cache line becomes DIRTY
// Write 0x50 → same index different tag
// → WRITEBACK old line
// → REFILL new line
//
// Waveform expectation:
// mem_req_valid toggles for writeback
// then refill sequence
// ====================================================

        axi_write(8'h10, 8'hAA);
        axi_write(8'h50, 8'hBB);

        // old line should now be evicted
        axi_read(8'h10); // miss again



// ====================================================
// TEST 5
// Intention:
// Verify invalid address detection in AXI slave.
//
// Expected:
// Address > 0x8F should generate DECERR.
//
// Waveform expectation:
// RRESP = 2'b11
// No memory access
// ====================================================

        axi_read(8'hF0);



        repeat(50) @(posedge ACLK);

        $display("Simulation finished");

        $finish;

    end

endmodule