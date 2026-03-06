module cache_controller (

    input  logic        clk,
    input  logic        rst,

    // CPU's request(coming through simple_interconnect)
    input  logic        req_valid,
    input  logic        req_write,
    input  logic [7:0]  req_addr,
    input  logic [7:0]  req_wdata,

    //  response to CPU(going through simple_interconnect)
    output logic        resp_ready,
    output logic [7:0]  resp_rdata,

    // Memory interface(cache <-> memory)
    output logic        mem_req_valid,
    output logic        mem_req_write,
    output logic [7:0]  mem_req_addr,
    output logic [7:0]  mem_req_wdata,

    input  logic        mem_resp_ready,
    input  logic [7:0]  mem_resp_rdata
);

    logic [1:0] offset;
    logic [1:0] index;
    logic [3:0] tag;

    assign offset = req_addr[1:0];
    assign index  = req_addr[3:2];
    assign tag    = req_addr[7:4];

    logic        valid [0:3];//4 cache lines, chosen by "index", [0:3] is for index, valid remains same for 1 cache line(4 bytes)
    logic        dirty [0:3]; //same as valid
    logic [3:0]  tag_array [0:3];//same as valid nd dirty , only tag is a 4 bit entity->[3:0]
    logic [31:0] data_array[0:3];

    integer i;

    typedef enum logic [1:0] {
        IDLE, //waiting for req
        WRITEBACK,//store back dirty line to mem
        REFILL //bring new data into cache from mem
    } state_t;

    state_t state;
    logic [1:0] byte_cnt;//which byte of cache line

    // Reset
    always_ff @(posedge clk or posedge rst) begin

    if (rst) begin
        state <= IDLE;
        byte_cnt <= 0;
        resp_ready <= 0;
        mem_req_valid <= 0;

        for (i = 0; i < 4; i++) begin
            valid[i] <= 0;
            dirty[i] <= 0;
            tag_array[i] <= 0;
            data_array[i] <= 0;
        end
    end

    else begin
//fsm
        resp_ready    <= 0;
        mem_req_valid <= 0;

        case (state)

        IDLE: begin //waiting for request from CPU
            if (req_valid) begin 

                if ( valid[index] && tag_array[index] == tag ) begin

                    $display("CACHE HIT addr=%h", req_addr);

                    resp_ready <= 1;

                    if (!req_write) begin
                    //read
                        case (offset)
                            2'b00: resp_rdata <= data_array[index][7:0];
                            2'b01: resp_rdata <= data_array[index][15:8];
                            2'b10: resp_rdata <= data_array[index][23:16];
                            2'b11: resp_rdata <= data_array[index][31:24];
                        endcase
                    end
                    else begin
                    //write
                        case (offset)
                            2'b00: data_array[index][7:0]   <= req_wdata;
                            2'b01: data_array[index][15:8]  <= req_wdata;
                            2'b10: data_array[index][23:16] <= req_wdata;
                            2'b11: data_array[index][31:24] <= req_wdata;
                        endcase
                        dirty[index] <= 1;
                    end

                end else begin

                    $display("CACHE MISS addr=%h", req_addr);

                    byte_cnt <= 0;

                    if ( valid[index] && dirty[index] ) begin
                        $display("WRITEBACK required index=%0d", index);
                        state <= WRITEBACK;
                    end
                    else begin
                        $display("REFILL start addr=%h", req_addr);
                        state <= REFILL;
                    end
                end
            end
        end

WRITEBACK: begin

            $display("WRITEBACK byte=%0d addr=%h data=%h",
                     byte_cnt,
                     {tag_array[index], index, byte_cnt},
                     data_array[index][byte_cnt*8 +: 8]);

//  send write request to memory
           mem_req_valid <= !mem_resp_ready; //request stays active until memory answersD
            mem_req_write <= 1;
            mem_req_addr  <= { tag_array[index], index, byte_cnt };//byte_cnt for offset
            mem_req_wdata <= data_array[index][byte_cnt*8 +: 8];

//memory completed one byte write , mem_resp_ready is generated for each of the 4 bytes written 
            if (mem_resp_ready) begin
            
                if (byte_cnt == 3) begin //if all 4bytes transferred from cache to memory,WRITEBACK finished
                    dirty[index] <= 0;// now, dirty bit reset to 0
                    byte_cnt <= 0;//next is REFILL, which also transfers 4 bytes, hence counter must restart
                    state <= REFILL;
                  end
                  
                  else begin byte_cnt <= byte_cnt + 1;
                  end
            end
        end


      //WRITEBACK → REFILL
REFILL: begin

    $display("REFILL byte=%0d addr=%h",
             byte_cnt,
             {tag, index, byte_cnt});

    // request memory read
    mem_req_valid <= !mem_resp_ready;  //request stays active until memory answers
    mem_req_write <= 0;
    mem_req_addr <= { tag, index, byte_cnt };//8 bit address

    if (mem_resp_ready) begin
        // store fetched byte into cache line
        data_array[index][byte_cnt*8 +: 8] <= mem_resp_rdata;

        if (byte_cnt == 3) begin //refill finished
            valid[index] <= 1;// since it has valid data from mem, set valid as 1
            tag_array[index] <= tag;

            //read after miss
            case (offset)
                2'b00: resp_rdata <= mem_resp_rdata;//mem_* are wires from simple_memory module , connecting to the wires going from cache to cpu
                //through simple interconnect
                2'b01: resp_rdata <= mem_resp_rdata;
                2'b10: resp_rdata <= mem_resp_rdata;
                2'b11: resp_rdata <= mem_resp_rdata;
            endcase

            resp_ready <= 1;   // tell CPU request finished, response is ready
            byte_cnt <= 0;
            state <= IDLE;
        end

        else begin
            byte_cnt <= byte_cnt + 1;//if byte_cnt is not =3 yet, increment
        end
    end
end

        endcase
    end
end
endmodule