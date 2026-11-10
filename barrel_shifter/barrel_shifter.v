module barrel_shifter #(parameter W = 32, parameter LOG = 5) (
    input      [W-1:0]   din,
    input      [LOG-1:0] shamt,
    input      [2:0]     op,
    output     [W-1:0]   dout
);
    reg signed [W-1:0] t;
    integer s, k;
    always @(*) begin
        t = din;
        for (s = 0; s < LOG; s = s + 1) begin
            k = 1 << s;
            if (shamt[s]) begin
                case (op)
                    3'b000: t = t << k;
                    3'b001: t = t >> k;
                    3'b010: t = t >>> k;
                    3'b011: t = (t << k) | (t >> (W-k));
                    3'b100: t = (t >> k) | (t << (W-k));
                    default: t = t;
                endcase
            end
        end
    end
    assign dout = t;
endmodule
