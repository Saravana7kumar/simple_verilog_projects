module vending_fsm (
    input  clk, rst,
    input  coin5, coin10,
    output reg dispense,
    output reg change
);
    localparam S0 = 2'd0, S5 = 2'd1, S10 = 2'd2;
    reg [1:0] state, next;

    always @(posedge clk or posedge rst)
        if (rst) state <= S0;
        else     state <= next;

    always @(*) begin
        next = state; dispense = 0; change = 0;
        case (state)
            S0:  if (coin5) next = S5;
                 else if (coin10) next = S10;
            S5:  if (coin5) next = S10;
                 else if (coin10) begin next = S0; dispense = 1; end
            S10: if (coin5) begin next = S0; dispense = 1; end
                 else if (coin10) begin next = S0; dispense = 1; change = 1; end
            default: next = S0;
        endcase
    end
endmodule
