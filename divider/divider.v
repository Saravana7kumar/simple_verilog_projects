module divider #(parameter W = 8) (
    input              clk, rst, start, signed_op,
    input  [W-1:0]     dividend, divisor,
    output reg [W-1:0] quotient, remainder,
    output reg         busy, done, div_by_zero, overflow
);
    reg [W-1:0] Q, D, a_orig;
    reg [W:0]   R;
    reg [7:0]   cnt;
    reg         sgn_a, sgn_b, sop;
    reg [W:0]   sh, nr;
    reg [W-1:0] nq;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Q <= 0; D <= 0; a_orig <= 0; R <= 0; cnt <= 0; sgn_a <= 0; sgn_b <= 0; sop <= 0;
            quotient <= 0; remainder <= 0; busy <= 0; done <= 0; div_by_zero <= 0; overflow <= 0;
        end else begin
            done <= 0;
            if (!busy) begin
                if (start) begin
                    sop    <= signed_op;
                    sgn_a  <= signed_op & dividend[W-1];
                    sgn_b  <= signed_op & divisor[W-1];
                    Q      <= (signed_op & dividend[W-1]) ? (~dividend + 1'b1) : dividend;   // |a|
                    D      <= (signed_op & divisor[W-1])  ? (~divisor  + 1'b1) : divisor;    // |b|
                    a_orig <= dividend;
                    R <= 0; cnt <= 0; busy <= 1;
                end
            end else begin
                sh = {R[W-1:0], Q[W-1]};
                if (sh >= {1'b0, D}) begin nr = sh - {1'b0, D}; nq = {Q[W-2:0], 1'b1}; end
                else                 begin nr = sh;             nq = {Q[W-2:0], 1'b0}; end
                R <= nr; Q <= nq; cnt <= cnt + 1;
                if (cnt == W-1) begin
                    busy <= 0; done <= 1;
                    div_by_zero <= (D == 0);
                    if (D == 0) begin
                        quotient <= {W{1'b1}}; remainder <= a_orig; overflow <= 0;
                    end else begin
                        quotient  <= (sgn_a ^ sgn_b) ? (~nq + 1'b1) : nq;
                        remainder <= sgn_a ? (~nr[W-1:0] + 1'b1) : nr[W-1:0];
                        overflow  <= sop & ~(sgn_a ^ sgn_b) & nq[W-1];
                    end
                end
            end
        end
    end
endmodule
