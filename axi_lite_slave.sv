module axi_lite_slave (

    input  logic        ACLK,
    input  logic        ARESETn,
    //reset is negated ie active low 

    // WRITE ADDRESS CHANNEL {master pov}
    input  logic [7:0]  AWADDR,
    input  logic        AWVALID,
    output logic        AWREADY,

    // WRITE DATA CHANNEL {master pov}
    input  logic [7:0]  WDATA,
    input  logic        WSTRB, // 1-bit for 8-bit bus
    input  logic        WVALID,
    output logic        WREADY,

    // WRITE RESPONSE CHANNEL (slave pov)
    output logic [1:0]  BRESP,
    output logic        BVALID,
    input  logic        BREADY,

    // READ ADDRESS CHANNEL   {master pov}
    input  logic [7:0]  ARADDR,
    input  logic        ARVALID,
    output logic        ARREADY,

    // READ DATA CHANNEL(slave pov)
    output logic [7:0]  RDATA,
    output logic [1:0]  RRESP,
    output logic        RVALID,
    input  logic        RREADY,

    // ===== Internal simple bus =====(slave <-> memory), not AXI signals
    output logic        req_valid,
    output logic        req_write,
    output logic [7:0]  req_addr,
    output logic [7:0]  req_wdata,

    input  logic        resp_ready,
    input  logic [7:0]  resp_rdata
);



    // Handshake fire signals (COMBINATIONAL)
    //input side
    logic aw_fire;
    logic w_fire;
    logic ar_fire;

//output side
logic b_fire;
logic r_fire;

    assign aw_fire = AWVALID && AWREADY;
    assign w_fire  = WVALID  && WREADY;
    assign ar_fire = ARVALID && ARREADY;
    
    assign b_fire = BVALID && BREADY;
    assign r_fire= RVALID && RREADY;
    //handshake signals as they become high only when both slave and master are ready


    // STORAGE REGISTERS 

//data nd address may not be recieved in the same cycle
//store one till the other one comes
    logic [7:0] saved_awaddr;
    logic [7:0] saved_wdata;
    logic [7:0] saved_araddr;//for read:just need the address which is to be read
  
  
  //for address range >3F(invalid address range)  
logic addr_invalid;

    
    logic  aw_received;//accepted write address already
    logic  w_received;//accepted write data already
    logic  ar_received; //accepted read address already



    // ------------------------------------------------
    // Generate write_fire / read_fire
    // ------------------------------------------------

    logic write_fire;
    logic read_fire;

    assign write_fire = aw_received && w_received;
    assign read_fire  = ar_received;

    // ------------------------------------------------
    // READY generation
    // ------------------------------------------------
    
 always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
        //initialise AXI signals
            AWREADY <= 0;//write input
            WREADY  <= 0;//write input
            ARREADY <= 0;//read input
        end
        
        else begin
            // Always ready when not busy(no payload recieved yet)
            AWREADY <= !aw_received;
            //Because once we accept an address, 
            //we don't want to accept another one until this write finishes.
            
           //Before handshake → aw_received = 0 → READY = 1
           //After handshake → aw_received = 1 → READY = 0
            WREADY  <= !w_received;
            ARREADY <= !ar_received;// block new read if previous not issued
        end
    end

    // ------------------------------------------------
    // CAPTURE WRITE CHANNELS
    // ------------------------------------------------

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            aw_received <= 0;
            w_received  <= 0;
        end
        else begin
            if (aw_fire) begin
//save this address for write handshake if it happens later            
                saved_awaddr <= AWADDR;
                aw_received  <= 1;
            end

            if (w_fire) begin
//save this address for address handshake if it happens later
                saved_wdata <= WDATA;
                w_received  <= 1;
            end

            // clear when write request issued
            if (write_fire)
            begin
                aw_received <= 0;
                w_received  <= 0;
            end
        end
    end


    // ------------------------------------------------
    //  CAPTURE READ CHANNEL
// -----------------------------------------

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            ar_received <= 0;
        end
        else begin
        //address handshake has occured
            if (ar_fire) begin
                saved_araddr <= ARADDR;
                ar_received  <= 1;
            end

            if (read_fire)
//once read operation is completed
                ar_received <= 0;
        end
    end


    

    // ------------------------------------------------
    // slave <-> internal bus
    // ------------------------------------------------

    logic pending_write;  // remember if current request was write

    always_comb begin
        addr_invalid = 0;
        if (write_fire)
            addr_invalid = (saved_awaddr > 8'h8F);
        else if (read_fire)
            addr_invalid = (saved_araddr > 8'h8F);
    end

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            req_valid     <= 0;
            pending_write <= 0;
        end
        else begin
            req_valid <= 0;  // default pulse

            if (write_fire && !addr_invalid) begin
            //invalid accesses won't reach cache/memory.
                req_valid     <= 1;
                req_write     <= 1;
                req_addr      <= saved_awaddr;
                req_wdata     <= saved_wdata;
                pending_write <= 1;
            end
            else if (read_fire && !addr_invalid) begin
                req_valid     <= 1;
                req_write     <= 0;
                req_addr      <= saved_araddr;
                pending_write <= 0;
            end
        end
    end


//response side:(slave to master)

    // ------------------------------------------------
    // WRITE RESPONSE (B channel):just status 
    // ------------------------------------------------
 

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            BVALID <= 0;
        end
        else begin
        
        
        // Invalid write address → DECERR
        if (write_fire && addr_invalid)
            BVALID <= 1;
 //we wait for address nd data reception to complete 
 //before sending response error ie DECERR
 
        else if (resp_ready && pending_write)
            BVALID <= 1;


        else if (b_fire)
        //b_fire =  BVALID && BREADY
            BVALID <= 0;
                //slave module can only clear slave signal
        end
    end

   assign BRESP = addr_invalid ? 2'b11 : 2'b00;
    //response code
    //00: normal r/w
    //01: EXOKAY(not used in axi-lite)
    //10: SLVERR(slave error)
    //11: decode error DECERR


    // ------------------------------------------------
    // READ RESPONSE (R channel): status +data
    // ------------------------------------------------
   
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            RVALID <= 0;
        end
        else begin
        
        
         // invalid read address
        if (read_fire && addr_invalid) begin
            RVALID <= 1;
            RDATA  <= 8'h00;
        end
            
        else if (resp_ready && !pending_write) begin
        //internal bus has given the data to slave
        //last request wasnt write: it was read
            RVALID <= 1; //status
            RDATA  <= resp_rdata; //data
        end
        
        else if (r_fire)
        //r_fire= RVALID && RREADY
            RVALID <= 0;
                //slave module can only clear slave signal
        end
    end

    assign RRESP = addr_invalid ? 2'b11 : 2'b00;

endmodule