`timescale 1ns/1ps
module divider_tb;
    reg clk = 0, rst = 1, start = 0, sop = 0;
    reg  [7:0] a, b;
    wire [7:0] q, r; wire busy, done, dz, ovf;
    integer i, j, errors = 0, checked = 0;
    integer eq, er;
    reg [7:0] exp_q, exp_r; reg exp_dz, exp_ovf;

    divider #(.W(8)) dut (.clk(clk), .rst(rst), .start(start), .signed_op(sop), .dividend(a), .divisor(b),
                          .quotient(q), .remainder(r), .busy(busy), .done(done), .div_by_zero(dz), .overflow(ovf));
    always #5 clk = ~clk;

    task run;
    begin
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;
        wait (done === 1'b1);
        checked = checked + 1;
        if (q !== exp_q || r !== exp_r || dz !== exp_dz || ovf !== exp_ovf) begin
            errors = errors + 1;
            if (errors < 10) $display("FAIL sop=%b a=%0h b=%0h q=%0h r=%0h dz=%b ovf=%b (exp %0h %0h %b %b)",
                                      sop, a, b, q, r, dz, ovf, exp_q, exp_r, exp_dz, exp_ovf);
        end
        @(negedge clk);
    end
    endtask

    initial begin
        #22 rst = 0;
        // ---- unsigned, exhaustive
        sop = 0;
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 256; j = j + 1) begin
                a = i; b = j;
                exp_dz = (j == 0); exp_ovf = 0;
                if (j == 0) begin exp_q = 8'hFF; exp_r = i; end
                else        begin exp_q = i / j; exp_r = i % j; end
                run;
            end
        // ---- signed, exhaustive
        sop = 1;
        for (i = -128; i < 128; i = i + 1)
            for (j = -128; j < 128; j = j + 1) begin
                a = i; b = j;
                exp_dz = (j == 0); exp_ovf = (i == -128 && j == -1);
                if (j == 0) begin exp_q = 8'hFF; exp_r = i; end
                else        begin eq = i / j; er = i % j; exp_q = eq; exp_r = er; end
                run;
            end
        $display("DIVIDER: %0d divisions checked (unsigned + signed, 8-bit exhaustive)", checked);
        if (errors == 0) $display("DIVIDER: PASS"); else $display("DIVIDER: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
