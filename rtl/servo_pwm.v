module servo_pwm #(
    parameter CLK_HZ = 1_000_000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pulse_us,
    output reg         servo
);
    localparam integer TPMS   = (CLK_HZ / 1000 > 0) ? CLK_HZ / 1000 : 1;
    localparam integer FRAME  = TPMS * 20;

    reg  [31:0] cnt;
    wire [31:0] high_ticks = (pulse_us * TPMS) / 1000;

    always @(posedge clk or posedge rst) begin
        if (rst) begin cnt <= 0; servo <= 1'b0; end
        else begin
            cnt   <= (cnt == FRAME - 1) ? 0 : cnt + 1'b1;
            servo <= (cnt < high_ticks);
        end
    end
endmodule
