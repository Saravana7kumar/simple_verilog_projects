module seven_seg_ctrl #(parameter REFRESH_DIV = 100_000) (
    input             clk, rst,
    input      [15:0] bcd,
    output reg [6:0]  seg,
    output     [3:0]  an
);
    reg [31:0] cnt;
    reg [1:0]  sel;
    reg [3:0]  digit;
    reg [6:0]  raw;  

    always @(posedge clk or posedge rst) begin
        if (rst) begin cnt <= 0; sel <= 0; end
        else if (cnt == REFRESH_DIV-1) begin cnt <= 0; sel <= sel + 1; end
        else cnt <= cnt + 1;
    end

    assign an = ~(4'b0001 << sel);

    always @(*) begin
        digit = bcd[sel*4 +: 4];
        case (digit)
            4'd0: raw = 7'b0111111;
            4'd1: raw = 7'b0000110;
            4'd2: raw = 7'b1011011;
            4'd3: raw = 7'b1001111;
            4'd4: raw = 7'b1100110;
            4'd5: raw = 7'b1101101;
            4'd6: raw = 7'b1111101;
            4'd7: raw = 7'b0000111;
            4'd8: raw = 7'b1111111;
            4'd9: raw = 7'b1101111;
            default: raw = 7'b0000000; 
        endcase
        seg = ~raw;
    end
endmodule
