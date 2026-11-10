`timescale 1ns/1ps
module seven_seg_ctrl_tb;
    reg clk = 0, rst = 1; reg [15:0] bcd = 16'h1234;
    wire [6:0] seg; wire [3:0] an;
    integer errors = 0, i, idx, seen_mask;
    reg [3:0] dig; reg [6:0] exp_seg;

    seven_seg_ctrl #(.REFRESH_DIV(4)) dut (.clk(clk), .rst(rst), .bcd(bcd), .seg(seg), .an(an));
    always #5 clk = ~clk;

    function [6:0] enc(input [3:0] d);
        case (d)
            0: enc = 7'b1000000; 1: enc = 7'b1111001; 2: enc = 7'b0100100; 3: enc = 7'b0110000;
            4: enc = 7'b0011001; 5: enc = 7'b0010010; 6: enc = 7'b0000010; 7: enc = 7'b1111000;
            8: enc = 7'b0000000; 9: enc = 7'b0010000; default: enc = 7'b1111111;
        endcase
    endfunction

    task scan(input [15:0] v);
    begin
        bcd = v; seen_mask = 0;
        repeat (2) @(negedge clk);
        for (i = 0; i < 40; i = i + 1) begin
            @(negedge clk);
            case (an)
                4'b1110: idx = 0; 4'b1101: idx = 1; 4'b1011: idx = 2; 4'b0111: idx = 3;
                default: idx = -1;
            endcase
            if (idx < 0) begin errors = errors + 1; $display("FAIL an not one-hot: %b", an); end
            else begin
                seen_mask = seen_mask | (1 << idx);
                dig = v[idx*4 +: 4]; exp_seg = enc(dig);
                if (seg !== exp_seg) begin
                    errors = errors + 1; $display("FAIL digit%0d=%0h seg=%b exp=%b", idx, dig, seg, exp_seg);
                end
            end
        end
        if (seen_mask !== 4'hF) begin errors = errors + 1; $display("FAIL not all digits multiplexed"); end
    end
    endtask

    initial begin
        $dumpfile("seven_seg.vcd"); $dumpvars(0, seven_seg_ctrl_tb);
        #22 rst = 0;
        scan(16'h1234); scan(16'h0000); scan(16'h9876); scan(16'h5019);
        scan(16'hA9F0);                       // invalid BCD digits -> blank
        if (errors == 0) $display("SEVEN SEG: PASS"); else $display("SEVEN SEG: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
