module pwm_gen #(parameter W = 16) (
    input            clk, rst, en,
    input  [W-1:0]   period,
    input  [W-1:0]   duty,
    output reg       pwm_out
);
    reg [W-1:0] cnt, per_r, duty_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 0; per_r <= period; duty_r <= duty; pwm_out <= 0;
        end else if (!en) begin
            cnt <= 0; pwm_out <= 0; per_r <= period; duty_r <= duty;
        end else begin
            if (cnt >= per_r - 1) begin
                cnt <= 0; per_r <= period; duty_r <= duty;
            end else cnt <= cnt + 1;
            pwm_out <= (cnt < duty_r);
        end
    end
endmodule
