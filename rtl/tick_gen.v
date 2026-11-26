module tick_gen #(
    parameter CLK_HZ = 1_000_000
)(
    input  wire clk,
    input  wire rst,
    output reg  tick_1ms,
    output reg  tick_10ms,
    output reg  tick_100ms
);
    localparam integer MS_DIV = (CLK_HZ / 1000 > 0) ? CLK_HZ / 1000 : 1;

    reg [31:0] cnt_ms;
    reg [3:0]  cnt_10;
    reg [3:0]  cnt_100;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt_ms     <= 0;
            cnt_10     <= 0;
            cnt_100    <= 0;
            tick_1ms   <= 1'b0;
            tick_10ms  <= 1'b0;
            tick_100ms <= 1'b0;
        end else begin
            tick_1ms   <= 1'b0;
            tick_10ms  <= 1'b0;
            tick_100ms <= 1'b0;
            if (cnt_ms == MS_DIV - 1) begin
                cnt_ms   <= 0;
                tick_1ms <= 1'b1;
                if (cnt_10 == 9) begin
                    cnt_10    <= 0;
                    tick_10ms <= 1'b1;
                    if (cnt_100 == 9) begin
                        cnt_100    <= 0;
                        tick_100ms <= 1'b1;
                    end else begin
                        cnt_100 <= cnt_100 + 1'b1;
                    end
                end else begin
                    cnt_10 <= cnt_10 + 1'b1;
                end
            end else begin
                cnt_ms <= cnt_ms + 1'b1;
            end
        end
    end
endmodule
