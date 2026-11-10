`timescale 1ns/1ps
module ram_ref #(parameter DW = 8, AW = 4, RDW_NEW = 0) (
    input clk, ena, wea, input [AW-1:0] addra, input [DW-1:0] dina,
    input enb, web, input [AW-1:0] addrb, input [DW-1:0] dinb,
    output reg [DW-1:0] douta, doutb, output reg cww, crw
);
    reg [DW-1:0] m [0:(1<<AW)-1];
    reg [DW-1:0] oa, ob; reg sm; integer i;
    initial for (i = 0; i < (1<<AW); i = i + 1) m[i] = 0;
    always @(posedge clk) begin
        sm = ena && enb && (addra == addrb);
        if (ena && !wea) begin oa = m[addra]; if (RDW_NEW && sm && web) oa = dinb; douta <= oa; end
        if (enb && !web) begin ob = m[addrb]; if (RDW_NEW && sm && wea) ob = dina; doutb <= ob; end
        if (enb && web) m[addrb] = dinb;      // B first, then A -> A wins
        if (ena && wea) m[addra] = dina;
        cww <= sm && wea && web;
        crw <= sm && (wea ^ web);
    end
endmodule

module dual_port_ram_tb;
    reg clk = 0;
    reg ena = 0, wea = 0, enb = 0, web = 0; reg [3:0] addra = 0, addrb = 0; reg [7:0] dina = 0, dinb = 0;
    wire [7:0] da0, db0, da1, db1, ra0, rb0, ra1, rb1; wire cww0, crw0, cww1, crw1, rcww0, rcrw0, rcww1, rcrw1;

    dual_port_ram #(.RDW_NEW(0)) d0 (.clk(clk), .ena(ena), .wea(wea), .addra(addra), .dina(dina), .douta(da0),
        .enb(enb), .web(web), .addrb(addrb), .dinb(dinb), .doutb(db0), .coll_ww(cww0), .coll_rw(crw0));
    dual_port_ram #(.RDW_NEW(1)) d1 (.clk(clk), .ena(ena), .wea(wea), .addra(addra), .dina(dina), .douta(da1),
        .enb(enb), .web(web), .addrb(addrb), .dinb(dinb), .doutb(db1), .coll_ww(cww1), .coll_rw(crw1));
    ram_ref #(.RDW_NEW(0)) r0 (.clk(clk), .ena(ena), .wea(wea), .addra(addra), .dina(dina), .enb(enb), .web(web),
        .addrb(addrb), .dinb(dinb), .douta(ra0), .doutb(rb0), .cww(rcww0), .crw(rcrw0));
    ram_ref #(.RDW_NEW(1)) r1 (.clk(clk), .ena(ena), .wea(wea), .addra(addra), .dina(dina), .enb(enb), .web(web),
        .addrb(addrb), .dinb(dinb), .douta(ra1), .doutb(rb1), .cww(rcww1), .crw(rcrw1));
    always #5 clk = ~clk;

    integer errors = 0, i, cw = 0, cr = 0;

    task cycle(input a_en, input a_we, input [3:0] a_ad, input [7:0] a_di,
               input b_en, input b_we, input [3:0] b_ad, input [7:0] b_di);
    begin
        @(negedge clk);
        ena = a_en; wea = a_we; addra = a_ad; dina = a_di;
        enb = b_en; web = b_we; addrb = b_ad; dinb = b_di;
    end endtask

    always @(negedge clk) begin
        if (da0 !== ra0 || db0 !== rb0 || cww0 !== rcww0 || crw0 !== rcrw0 ||
            da1 !== ra1 || db1 !== rb1 || cww1 !== rcww1 || crw1 !== rcrw1) begin
            errors = errors + 1;
            if (errors < 10) $display("MISMATCH t=%0t A:%h/%h B:%h/%h (mode0)  A:%h/%h B:%h/%h (mode1) flags %b%b %b%b",
                $time, da0, ra0, db0, rb0, da1, ra1, db1, rb1, cww0, crw0, cww1, crw1);
        end
        if (cww0) cw = cw + 1;
        if (crw0) cr = cr + 1;
    end

    initial begin
        $dumpfile("dpram.vcd"); $dumpvars(0, dual_port_ram_tb);
        cycle(1,1,5,8'h11, 0,0,0,0);                                
        cycle(1,0,5,0,     1,1,9,8'h99);                              
        cycle(1,0,9,0,     1,0,5,0);                                 
        cycle(0,0,0,0,     0,0,0,0);
        if (da0 !== 8'h99 || db0 !== 8'h11) begin errors = errors + 1; $display("FAIL dual read A=%h B=%h", da0, db0); end
        cycle(1,1,5,8'h22, 1,1,5,8'h33);                             
        cycle(1,0,5,0,     0,0,0,0);
        cycle(0,0,0,0,     0,0,0,0);
        if (da0 !== 8'h22) begin errors = errors + 1; $display("FAIL WW priority: mem[5]=%h exp 22", da0); end
        cycle(1,1,5,8'h44, 1,0,5,0);                              
        cycle(0,0,0,0,     0,0,0,0);
        if (db0 !== 8'h22) begin errors = errors + 1; $display("FAIL read-first: got %h exp 22", db0); end
        if (db1 !== 8'h44) begin errors = errors + 1; $display("FAIL write-through: got %h exp 44", db1); end
        if (crw0 !== 1'b1) begin errors = errors + 1; $display("FAIL coll_rw flag"); end
        cycle(0,0,0,0,     1,0,5,0);                                 
        cycle(0,0,0,0,     0,0,0,0);
        if (db0 !== 8'h44 || db1 !== 8'h44) begin errors = errors + 1; $display("FAIL post-collision read %h %h", db0, db1); end
        for (i = 0; i < 20000; i = i + 1)
            cycle($urandom % 5 != 0, $urandom % 2, $urandom % 4, $urandom,
                  $urandom % 5 != 0, $urandom % 2, $urandom % 4, $urandom);
        cycle(0,0,0,0, 0,0,0,0); cycle(0,0,0,0, 0,0,0,0);
        $display("DUAL-PORT RAM: %0d write-write and %0d read/write collisions seen", cw, cr);
        if (errors == 0) $display("DUAL-PORT RAM: PASS"); else $display("DUAL-PORT RAM: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
