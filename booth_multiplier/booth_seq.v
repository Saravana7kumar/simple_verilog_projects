module booth_seq #(parameter W = 8) (
    input                       clk, rst, start,
    input  signed [W-1:0]       multiplicand, multiplier,
    output reg signed [2*W-1:0] product,
    output reg                  busy, done
);
    reg signed [W-1:0] M, Q;
    reg signed [W:0]   A;          
    reg                Q1;
    reg [7:0]          cnt;
    reg signed [W:0]   tA;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            M <= 0; Q <= 0; A <= 0; Q1 <= 0; cnt <= 0; product <= 0; busy <= 0; done <= 0;
        end else begin
            done <= 0;
            if (!busy) begin
                if (start) begin
                    M <= multiplicand; Q <= multiplier; A <= 0; Q1 <= 0; cnt <= 0; busy <= 1;
                end
            end else begin
                case ({Q[0], Q1})
                    2'b01:   tA = A + {M[W-1], M};
                    2'b10:   tA = A - {M[W-1], M};
                    default: tA = A;
                endcase
                // arithmetic shift right of {tA, Q, Q1}
                {A, Q, Q1} <= {tA[W], tA, Q};
                cnt <= cnt + 1;
                if (cnt == W-1) begin
                    product <= {tA[W:1], tA[0], Q[W-1:1]};
                    busy <= 0; done <= 1;
                end
            end
        end
    end
endmodule
