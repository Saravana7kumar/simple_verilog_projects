`timescale 1ns/1ps
module pwm_gen_tb;
    reg clk = 0, rst = 1, en = 1; reg [15:0] period = 20, duty = 5; wire pwm_out;
    integer errors = 0, high, i, prev_p;
    pwm_gen dut (.clk(clk), .rst(rst), .en(en), .period(period), .duty(duty), .pwm_out(pwm_out));
    always #5 clk = ~clk;
    task measure(input [15:0] p, input [15:0] d);
        integer exp_h, w;
    begin
        @(negedge clk); period = p; duty = d;
        repeat (2*prev_p + 2*p + 4) @(negedge clk);     
        for (w = 0; w < 3; w = w + 1) begin          
            high = 0;
            for (i = 0; i < p; i = i + 1) begin @(negedge clk); if (pwm_out) high = high + 1; end
            exp_h = (d >= p) ? p : d;
            if (high !== exp_h) begin
                errors = errors + 1; $display("FAIL period=%0d duty=%0d high=%0d exp=%0d", p, d, high, exp_h);
            end
        end
        prev_p = p;
    end
    endtask

    initial begin
        $dumpfile("pwm.vcd"); $dumpvars(0, pwm_gen_tb);
        prev_p = 20;
        #22 rst = 0;
        measure(20, 5);  
        measure(20, 10);  
        measure(20, 15); 
        measure(20, 0);  
        measure(20, 20); 
        measure(50, 7);   
        measure(10, 3);
        measure(100, 33);
        // disable -> output low
        @(negedge clk); en = 0; repeat (3) @(negedge clk);
        if (pwm_out !== 0) begin errors = errors + 1; $display("FAIL en=0 output not low"); end
        if (errors == 0) $display("PWM: PASS"); else $display("PWM: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
