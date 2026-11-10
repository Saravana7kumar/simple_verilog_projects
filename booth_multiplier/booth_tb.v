`timescale 1ns/1ps
module booth_tb;
    reg clk = 0, rst = 1, start = 0;
    reg signed [7:0] a, b;
    wire signed [15:0] p_comb, p_seq;
    wire busy, done;
    integer i, j, errors = 0, checked = 0;

    booth_r4  #(.W(8)) u_comb (.a(a), .b(b), .p(p_comb));
    booth_seq #(.W(8)) u_seq  (.clk(clk), .rst(rst), .start(start), .multiplicand(a), .multiplier(b),
                               .product(p_seq), .busy(busy), .done(done));
    always #5 clk = ~clk;

    initial begin
        #22 rst = 0;
        for (i = -128; i < 128; i = i + 1)
            for (j = -128; j < 128; j = j + 1) begin
                @(negedge clk); a = i; b = j; start = 1; #1;
                checked = checked + 1;
                if (p_comb !== i*j) begin errors = errors + 1;
                    if (errors < 10) $display("FAIL r4  %0d*%0d = %0d (got %0d)", i, j, i*j, p_comb); end
                @(negedge clk); start = 0;
                wait (done === 1'b1);
                if (p_seq !== i*j) begin errors = errors + 1;
                    if (errors < 10) $display("FAIL seq %0d*%0d = %0d (got %0d)", i, j, i*j, p_seq); end
                @(negedge clk);
            end
        $display("BOOTH: %0d products checked (radix-4 comb + radix-2 seq)", checked);
        if (errors == 0) $display("BOOTH: PASS"); else $display("BOOTH: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
