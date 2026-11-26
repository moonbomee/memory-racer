module seg7_dec (
    input  wire [4:0] code,
    output reg  [7:0] seg
);
    always @(*) begin
        case (code)
            5'd0:  seg = 8'b1111_1100;
            5'd1:  seg = 8'b0110_0000;
            5'd2:  seg = 8'b1101_1010;
            5'd3:  seg = 8'b1111_0010;
            5'd4:  seg = 8'b0110_0110;
            5'd5:  seg = 8'b1011_0110;
            5'd6:  seg = 8'b1011_1110;
            5'd7:  seg = 8'b1110_0000;
            5'd8:  seg = 8'b1111_1110;
            5'd9:  seg = 8'b1111_0110;
            5'd11: seg = 8'b0001_0000;
            5'd12: seg = 8'b0000_0010;
            default: seg = 8'b0000_0000;
        endcase
    end
endmodule

module seg8_scan (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_1ms,
    input  wire [39:0] codes,
    output wire [7:0]  seg_data,
    output reg  [7:0]  seg_com
);
    reg  [2:0] idx;
    wire [4:0] cur = codes[idx*5 +: 5];

    seg7_dec u_dec (.code(cur), .seg(seg_data));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            idx     <= 3'd0;
            seg_com <= 8'hFF;
        end else if (tick_1ms) begin
            idx     <= idx + 1'b1;
            seg_com <= ~(8'b0000_0001 << (idx + 1'b1));
        end
    end
endmodule
