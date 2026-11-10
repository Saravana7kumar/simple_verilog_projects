module booth_r4 #(parameter W = 8) (
    input  signed [W-1:0]   a, b,
    output reg signed [2*W-1:0] p
);
    integer i;
    reg [W:0] bx;          
    reg signed [2*W-1:0] a_ext, pp;
    always @(*) begin
        a_ext = a;                      
        bx    = {b, 1'b0};
        p     = 0;
        for (i = 0; i < W/2; i = i + 1) begin
            case (bx[2*i +: 3])
                3'b000, 3'b111: pp = 0;
                3'b001, 3'b010: pp = a_ext;
                3'b011:         pp = a_ext <<< 1;
                3'b100:         pp = -(a_ext <<< 1);
                default:        pp = -a_ext;      
            endcase
            p = p + (pp <<< (2*i));
        end
    end
endmodule
