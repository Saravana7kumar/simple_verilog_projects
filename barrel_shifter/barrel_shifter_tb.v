`timescale 1ns/1ps
module barrel_shifter_tb;
    // 8-bit: exhaustive
    reg  [7:0] d8; reg [2:0] n8; reg [2:0] op; wire [7:0] y8;
    barrel_shifter #(.W(8), .LOG(3)) u8 (.din(d8), .shamt(n8), .op(op), .dout(y8));
    // 32-bit: random
    reg  [31:0] d32; reg [4:0] n32; wire [31:0] y32;
    barrel_shifter #(.W(32), .LOG(5)) u32 (.din(d32), .shamt(n32), .op(op), .dout(y32));

    integer i, n, o, errors = 0, tests = 0;
    reg [15:0]  dd8;  reg [63:0] dd32;
    reg [7:0]   e8;   reg [31:0] e32;

    task exp8; begin
        dd8 = {d8, d8};
        case (op)
            0: e8 = d8 << n8;
            1: e8 = d8 >> n8;
            2: e8 = $signed(d8) >>> n8;
            3: e8 = (dd8 << n8) >> 8;
            4: e8 = dd8 >> n8;
            default: e8 = d8;
        endcase
    end endtask
    task exp32; begin
        dd32 = {d32, d32};
        case (op)
            0: e32 = d32 << n32;
            1: e32 = d32 >> n32;
            2: e32 = $signed(d32) >>> n32;
            3: e32 = (dd32 << n32) >> 32;
            4: e32 = dd32 >> n32;
            default: e32 = d32;
        endcase
    end endtask

    initial begin
        for (o = 0; o < 5; o = o + 1)
            for (i = 0; i < 256; i = i + 1)
                for (n = 0; n < 8; n = n + 1) begin
                    op = o; d8 = i; n8 = n; d32 = 0; n32 = 0; #1; exp8; tests = tests + 1;
                    if (y8 !== e8) begin errors = errors + 1;
                        if (errors < 10) $display("FAIL W8 op=%0d d=%h n=%0d y=%h exp=%h", o, d8, n, y8, e8); end
                end
        for (i = 0; i < 20000; i = i + 1) begin
            op = $urandom % 5; d32 = $urandom; n32 = $urandom; d8 = 0; n8 = 0; #1; exp32; tests = tests + 1;
            if (y32 !== e32) begin errors = errors + 1;
                if (errors < 10) $display("FAIL W32 op=%0d d=%h n=%0d y=%h exp=%h", op, d32, n32, y32, e32); end
        end
        // corner: sign bit with SRA, shift 31
        op = 2; d32 = 32'h8000_0000; n32 = 31; #1;
        if (y32 !== 32'hFFFF_FFFF) begin errors = errors + 1; $display("FAIL SRA corner"); end
        $display("BARREL SHIFTER: %0d vectors", tests);
        if (errors == 0) $display("BARREL SHIFTER: PASS"); else $display("BARREL SHIFTER: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
