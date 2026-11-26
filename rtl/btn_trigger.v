module btn_trigger #(
    parameter N = 12
)(
    input  wire         clk,
    input  wire         rst,
    input  wire         tick_10ms,
    input  wire [N-1:0] btn_in,
    output reg  [N-1:0] pulse
);
    reg [N-1:0] sync1, sync2, stable, prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync1  <= 0;
            sync2  <= 0;
            stable <= 0;
            prev   <= 0;
            pulse  <= 0;
        end else begin
            sync1 <= btn_in;
            sync2 <= sync1;
            if (tick_10ms)
                stable <= sync2;
            prev  <= stable;
            pulse <= stable & ~prev;
        end
    end
endmodule
