module apb_slave_model #(parameter WAITS = 0, parameter [11:0] ERR_OFF = 12'hFFC) (
    input         pclk, presetn, psel, penable, pwrite,
    input  [31:0] paddr, pwdata,
    input  [3:0]  pstrb,
    output [31:0] prdata,
    output        pready, pslverr
);
    reg [31:0] mem [0:63];
    reg [3:0]  wc;
    reg [31:0] tmp;
    integer i;
    initial for (i = 0; i < 64; i = i + 1) mem[i] = 32'h0;

    wire acc = psel & penable;
    assign pready  = acc & (wc == WAITS);
    assign pslverr = pready & (paddr[11:0] == ERR_OFF);
    assign prdata  = (pready && !pwrite && !pslverr) ? mem[paddr[7:2]] : 32'h0;

    always @(posedge pclk or negedge presetn)
        if (!presetn) wc <= 0;
        else if (acc) wc <= (wc == WAITS) ? 4'd0 : wc + 1'b1;
        else wc <= 0;

    always @(posedge pclk)
        if (pready && pwrite && !pslverr) begin
            tmp = mem[paddr[7:2]];
            if (pstrb[0]) tmp[7:0]   = pwdata[7:0];
            if (pstrb[1]) tmp[15:8]  = pwdata[15:8];
            if (pstrb[2]) tmp[23:16] = pwdata[23:16];
            if (pstrb[3]) tmp[31:24] = pwdata[31:24];
            mem[paddr[7:2]] <= tmp;
        end
endmodule
