`timescale 1ns/1ps
module vending_fsm_tb;
    reg clk = 0, rst = 1, coin5 = 0, coin10 = 0;
    wire dispense, change;
    integer errors = 0;
    vending_fsm dut (.clk(clk), .rst(rst), .coin5(coin5), .coin10(coin10),
                     .dispense(dispense), .change(change));
    always #5 clk = ~clk;

    task coin(input c5, input c10, input exp_d, input exp_c);
    begin
        @(negedge clk); coin5 = c5; coin10 = c10; #1;
        if (dispense !== exp_d || change !== exp_c) begin
            errors = errors + 1;
            $display("FAIL t=%0t c5=%b c10=%b disp=%b chg=%b (exp %b %b)",
                     $time, c5, c10, dispense, change, exp_d, exp_c);
        end
        @(negedge clk); coin5 = 0; coin10 = 0;
    end
    endtask

    initial begin
        $dumpfile("vending_fsm.vcd"); $dumpvars(0, vending_fsm_tb);
        #12 rst = 0;
        // 5+5+5
        coin(1,0,0,0); coin(1,0,0,0); coin(1,0,1,0);
        // 10+5
        coin(0,1,0,0); coin(1,0,1,0);
        // 5+10
        coin(1,0,0,0); coin(0,1,1,0);
        // 10+10 -> change
        coin(0,1,0,0); coin(0,1,1,1);
        // reset in the middle: 5, reset, then 10+5 must still need full price
        coin(1,0,0,0);
        @(negedge clk); rst = 1; @(negedge clk); rst = 0;
        coin(0,1,0,0); coin(1,0,1,0);
        // idle cycles: no outputs
        repeat (3) coin(0,0,0,0);
        if (errors == 0) $display("VENDING FSM: PASS"); else $display("VENDING FSM: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
