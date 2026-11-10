module axi_apb_bridge #(
    parameter ADDR_W  = 32,
    parameter DATA_W  = 32,
    parameter NUM_SLV = 4,
    parameter SEL_W   = 2,           // log2(NUM_SLV)
    parameter SEL_LSB = 12           // 4 KB per peripheral
) (
    input                        aclk, aresetn,
    input      [ADDR_W-1:0]      awaddr,  input awvalid, output awready,
    input      [DATA_W-1:0]      wdata,   input [DATA_W/8-1:0] wstrb, input wvalid, output wready,
    output reg [1:0]             bresp,   output reg bvalid, input bready,
    input      [ADDR_W-1:0]      araddr,  input arvalid, output arready,
    output reg [DATA_W-1:0]      rdata,   output reg [1:0] rresp, output reg rvalid, input rready,
    output reg [ADDR_W-1:0]      paddr,
    output reg [NUM_SLV-1:0]     psel,
    output reg                   penable, pwrite,
    output reg [DATA_W-1:0]      pwdata,
    output reg [DATA_W/8-1:0]    pstrb,
    input  [NUM_SLV*DATA_W-1:0]  prdata,
    input  [NUM_SLV-1:0]         pready, pslverr
);
    localparam IDLE = 3'd0, SETUP = 3'd1, ACCESS = 3'd2, RESP = 3'd3;
    reg [2:0]         st;
    reg               aw_got, w_got, lat_wr;
    reg [ADDR_W-1:0]  aw_addr;
    reg [DATA_W-1:0]  w_data;
    reg [DATA_W/8-1:0] w_strb;
    assign awready = (st == IDLE) && !aw_got;
    assign wready  = (st == IDLE) && !w_got;
    assign arready = (st == IDLE) && !aw_got && !w_got && !awvalid && !wvalid;
    wire wr_launch = (st == IDLE) && aw_got && w_got;
    wire rd_launch = (st == IDLE) && arvalid && arready;
    integer i;
    reg [DATA_W-1:0] prd_sel; reg pr_sel, pe_sel;
    always @(*) begin
        prd_sel = 0; pr_sel = 0; pe_sel = 0;
        for (i = 0; i < NUM_SLV; i = i + 1)
            if (psel[i]) begin
                prd_sel = prd_sel | prdata[i*DATA_W +: DATA_W];
                pr_sel  = pr_sel  | pready[i];
                pe_sel  = pe_sel  | pslverr[i];
            end
    end

    reg [ADDR_W-1:0] l_addr;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            st <= IDLE; aw_got <= 0; w_got <= 0; lat_wr <= 0; aw_addr <= 0; w_data <= 0; w_strb <= 0;
            bresp <= 0; bvalid <= 0; rdata <= 0; rresp <= 0; rvalid <= 0;
            paddr <= 0; psel <= 0; penable <= 0; pwrite <= 0; pwdata <= 0; pstrb <= 0;
        end else begin
            case (st)
                IDLE: begin
                    if (awvalid && awready) begin aw_addr <= awaddr; aw_got <= 1; end
                    if (wvalid  && wready ) begin w_data <= wdata; w_strb <= wstrb; w_got <= 1; end
                    if (wr_launch || rd_launch) begin
                        l_addr = wr_launch ? aw_addr : araddr;
                        lat_wr <= wr_launch;
                        aw_got <= 0; w_got <= 0;
                        if ((l_addr >> (SEL_LSB + SEL_W)) != 0) begin      // decode error
                            st <= RESP;
                            if (wr_launch) begin bvalid <= 1; bresp <= 2'b10; end
                            else begin rvalid <= 1; rresp <= 2'b10; rdata <= 0; end
                        end else begin
                            paddr  <= l_addr;
                            psel   <= ({{(NUM_SLV-1){1'b0}}, 1'b1}) << l_addr[SEL_LSB +: SEL_W];
                            pwrite <= wr_launch;
                            pwdata <= w_data;
                            pstrb  <= wr_launch ? w_strb : {(DATA_W/8){1'b0}};
                            penable <= 0;
                            st <= SETUP;
                        end
                    end
                end
                SETUP: begin penable <= 1; st <= ACCESS; end
                ACCESS: if (pr_sel) begin
                    psel <= 0; penable <= 0; st <= RESP;
                    if (lat_wr) begin bvalid <= 1; bresp <= pe_sel ? 2'b10 : 2'b00; end
                    else begin rvalid <= 1; rresp <= pe_sel ? 2'b10 : 2'b00; rdata <= pe_sel ? {DATA_W{1'b0}} : prd_sel; end
                end
                RESP: begin
                    if (bvalid && bready) begin bvalid <= 0; st <= IDLE; end
                    if (rvalid && rready) begin rvalid <= 0; st <= IDLE; end
                end
                default: st <= IDLE;
            endcase
        end
    end
endmodule
