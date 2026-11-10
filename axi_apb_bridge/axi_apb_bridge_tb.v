`timescale 1ns/1ps
module axi_apb_bridge_tb;
    reg aclk = 0, aresetn = 0;
    reg [31:0] awaddr = 0, wdata = 0, araddr = 0;
    reg [3:0]  wstrb = 0;
    reg awvalid = 0, wvalid = 0, arvalid = 0, bready = 0, rready = 0;
    wire awready, wready, arready, bvalid, rvalid;
    wire [1:0] bresp, rresp; wire [31:0] rdata;
    wire [31:0] paddr, pwdata; wire [3:0] psel, pstrb, pready, pslverr; wire penable, pwrite;
    wire [127:0] prdata;

    axi_apb_bridge dut (.aclk(aclk), .aresetn(aresetn),
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready),
        .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite), .pwdata(pwdata), .pstrb(pstrb),
        .prdata(prdata), .pready(pready), .pslverr(pslverr));

    genvar g;
    generate for (g = 0; g < 4; g = g + 1) begin : slv
        apb_slave_model #(.WAITS((g == 1) ? 1 : (g == 2) ? 3 : 0)) u (
            .pclk(aclk), .presetn(aresetn), .psel(psel[g]), .penable(penable), .pwrite(pwrite),
            .paddr(paddr), .pwdata(pwdata), .pstrb(pstrb),
            .prdata(prdata[g*32 +: 32]), .pready(pready[g]), .pslverr(pslverr[g]));
    end endgenerate

    always #5 aclk = ~aclk;

    integer errors = 0, apb_accesses = 0, i, k;
    reg [31:0] sb [0:255];                       // scoreboard {slave[1:0], word[5:0]}
    reg [31:0] rd; reg [1:0] resp;

    // ---------- APB protocol monitor ----------
    reg prev_setup = 0; reg [31:0] prev_paddr, prev_pwdata; reg prev_pwrite;
    always @(posedge aclk) if (aresetn) begin
        if (penable && !(|psel))   begin errors = errors + 1; $display("FAIL penable without psel"); end
        if ((|psel) && ((psel & (psel - 1)) != 0)) begin errors = errors + 1; $display("FAIL psel not one-hot"); end
        if (penable && (|psel) && (paddr !== prev_paddr || pwrite !== prev_pwrite || (pwrite && pwdata !== prev_pwdata))) begin
            errors = errors + 1; $display("FAIL APB signals changed during access");
        end
        if ((|psel) && penable && (|(psel & pready))) apb_accesses = apb_accesses + 1;
        prev_setup <= (|psel) && !penable;
        prev_paddr <= paddr; prev_pwdata <= pwdata; prev_pwrite <= pwrite;
    end
    // SETUP phase must precede every ACCESS phase
    reg pen_q = 0, psel_q = 0;
    always @(posedge aclk) begin
        if (aresetn && penable && !pen_q && !prev_setup) begin errors = errors + 1; $display("FAIL access phase without setup phase"); end
        pen_q <= penable; psel_q <= |psel;
    end

    // ---------- AXI master tasks ----------
    // mode 0: AW and W together, 1: AW first (W 3 cycles later), 2: W first
    task axi_write(input [31:0] a, input [31:0] d, input [3:0] s, input integer mode, output [1:0] r);
    begin
        fork
            begin
                if (mode == 2) repeat (3) @(negedge aclk);
                @(negedge aclk); awaddr = a; awvalid = 1;
                @(posedge aclk); while (!awready) @(posedge aclk);
                @(negedge aclk); awvalid = 0;
            end
            begin
                if (mode == 1) repeat (3) @(negedge aclk);
                @(negedge aclk); wdata = d; wstrb = s; wvalid = 1;
                @(posedge aclk); while (!wready) @(posedge aclk);
                @(negedge aclk); wvalid = 0;
            end
        join
        bready = 1;
        @(posedge aclk); while (!bvalid) @(posedge aclk);
        r = bresp;
        @(negedge aclk); bready = 0;
    end
    endtask

    task axi_read(input [31:0] a, output [31:0] d, output [1:0] r);
    begin
        @(negedge aclk); araddr = a; arvalid = 1;
        @(posedge aclk); while (!arready) @(posedge aclk);
        @(negedge aclk); arvalid = 0; rready = 1;
        @(posedge aclk); while (!rvalid) @(posedge aclk);
        d = rdata; r = rresp;
        @(negedge aclk); rready = 0;
    end
    endtask

    function [7:0] sidx(input [31:0] a); sidx = {a[13:12], a[7:2]}; endfunction

    task wr_chk(input [31:0] a, input [31:0] d, input [3:0] s, input integer mode);
        reg [31:0] t;
    begin
        axi_write(a, d, s, mode, resp);
        if (resp !== 2'b00) begin errors = errors + 1; $display("FAIL write %h resp=%b", a, resp); end
        t = sb[sidx(a)];
        if (s[0]) t[7:0] = d[7:0]; if (s[1]) t[15:8] = d[15:8];
        if (s[2]) t[23:16] = d[23:16]; if (s[3]) t[31:24] = d[31:24];
        sb[sidx(a)] = t;
    end endtask

    task rd_chk(input [31:0] a);
    begin
        axi_read(a, rd, resp);
        if (resp !== 2'b00 || rd !== sb[sidx(a)]) begin
            errors = errors + 1; $display("FAIL read %h got %h resp=%b exp %h", a, rd, resp, sb[sidx(a)]);
        end
    end endtask

    integer acc_before;
    initial begin
        $dumpfile("axi_apb.vcd"); $dumpvars(0, axi_apb_bridge_tb);
        for (i = 0; i < 256; i = i + 1) sb[i] = 0;
        #27 aresetn = 1;

        // 1. directed write/read on each peripheral (0,1,3 wait states)
        for (k = 0; k < 4; k = k + 1) begin
            wr_chk((k << 12) | 32'h10, 32'hC0DE0000 + k, 4'hF, 0);
            rd_chk((k << 12) | 32'h10);
        end
        // 2. byte strobes
        wr_chk(32'h1020, 32'h11223344, 4'hF, 0);
        wr_chk(32'h1020, 32'hAABBCCDD, 4'b0101, 0);
        rd_chk(32'h1020);
        if (rd !== 32'h11BB33DD) begin errors = errors + 1; $display("FAIL strobe result %h", rd); end
        // 3. AW/W arriving at different times
        wr_chk(32'h2040, 32'hDEADBEEF, 4'hF, 1); rd_chk(32'h2040);
        wr_chk(32'h2044, 32'hCAFEF00D, 4'hF, 2); rd_chk(32'h2044);
        // 4. PSLVERR  -> SLVERR (write and read) and memory not modified
        axi_write(32'h0FFC, 32'h12345678, 4'hF, 0, resp);
        if (resp !== 2'b10) begin errors = errors + 1; $display("FAIL expected SLVERR on write, got %b", resp); end
        axi_read(32'h3FFC, rd, resp);
        if (resp !== 2'b10) begin errors = errors + 1; $display("FAIL expected SLVERR on read, got %b", resp); end
        // 5. decode error: outside APB map, no APB access generated
        acc_before = apb_accesses;
        axi_write(32'h0000_4000, 32'h1, 4'hF, 0, resp);
        if (resp !== 2'b10) begin errors = errors + 1; $display("FAIL decode error write resp=%b", resp); end
        axi_read(32'h8000_0000, rd, resp);
        if (resp !== 2'b10) begin errors = errors + 1; $display("FAIL decode error read resp=%b", resp); end
        if (apb_accesses !== acc_before) begin errors = errors + 1; $display("FAIL APB access on decode error"); end
        // 6. random traffic
        for (i = 0; i < 300; i = i + 1) begin
            k = $urandom % 4;
            if ($urandom % 2) wr_chk((k << 12) | (($urandom % 64) << 2), $urandom, $urandom | 4'h1, $urandom % 3);
            else              rd_chk((k << 12) | (($urandom % 64) << 2));
        end
        // 7. full read-back sweep
        for (k = 0; k < 4; k = k + 1)
            for (i = 0; i < 64; i = i + 1) rd_chk((k << 12) | (i << 2));
        if (errors == 0) $display("AXI-APB BRIDGE: PASS (%0d APB accesses)", apb_accesses);
        else $display("AXI-APB BRIDGE: FAIL (%0d errors)", errors);
        $finish;
    end
    initial begin #50_000_000; $display("AXI-APB BRIDGE: TIMEOUT"); $finish; end
endmodule
