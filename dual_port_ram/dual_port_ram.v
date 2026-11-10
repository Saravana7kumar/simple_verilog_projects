module dual_port_ram #(
    parameter DW = 8,
    parameter AW = 4,
    parameter RDW_NEW = 0
) (
    input               clk,
    // Port A
    input               ena, wea,
    input  [AW-1:0]     addra,
    input  [DW-1:0]     dina,
    output reg [DW-1:0] douta,
    // Port B
    input               enb, web,
    input  [AW-1:0]     addrb,
    input  [DW-1:0]     dinb,
    output reg [DW-1:0] doutb,
    // collision flags
    output reg          coll_ww, coll_rw
);
    reg [DW-1:0] mem [0:(1<<AW)-1];
    integer i;
    initial for (i = 0; i < (1<<AW); i = i + 1) mem[i] = {DW{1'b0}};

    wire same = ena && enb && (addra == addrb);

    always @(posedge clk) begin
        // writes (A wins a write-write collision)
        if (ena && wea) mem[addra] <= dina;
        if (enb && web && !(same && wea)) mem[addrb] <= dinb;
        // reads (see old contents unless write-through requested)
        if (ena && !wea) douta <= (RDW_NEW && same && web) ? dinb : mem[addra];
        if (enb && !web) doutb <= (RDW_NEW && same && wea) ? dina : mem[addrb];
        // collision detection
        coll_ww <= same && wea && web;
        coll_rw <= same && (wea ^ web);
    end
endmodule
