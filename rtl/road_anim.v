module road_anim (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_10ms,
    input  wire       active,
    input  wire       wrong_evt,
    input  wire       finish_evt,
    output reg        lane,
    output reg  [3:0] obst_col,
    output reg        crash,
    output reg        car_on,
    output reg  [3:0] flag_col,
    output wire       busy,
    output reg        finish_done
);
    localparam A_RUN = 3'd0, A_OBST = 3'd1, A_CRASH = 3'd2, A_BLINK = 3'd3,
               A_FLAG = 3'd4, A_FLAGHOLD = 3'd5, A_END = 3'd6;

    reg [2:0] st;
    reg [5:0] t;
    reg [5:0] lane_t;
    reg [2:0] blinks;

    assign busy = (st == A_OBST) || (st == A_CRASH) || (st == A_BLINK);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            st <= A_RUN; t <= 0; lane_t <= 0; blinks <= 0;
            lane <= 1'b0; obst_col <= 0; crash <= 1'b0; car_on <= 1'b1;
            flag_col <= 0; finish_done <= 1'b0;
        end else if (!active) begin
            st <= A_RUN; t <= 0; lane_t <= 0;
            obst_col <= 0; crash <= 1'b0; car_on <= 1'b1;
            flag_col <= 0; finish_done <= 1'b0;
        end else begin
            if (tick_10ms && st != A_END) begin
                if (lane_t == 29) begin lane_t <= 0; lane <= ~lane; end
                else lane_t <= lane_t + 1'b1;
            end

            if (finish_evt) begin
                st <= A_FLAG; t <= 0; flag_col <= 4'd12;
                obst_col <= 0; crash <= 1'b0; car_on <= 1'b1;
            end else if (wrong_evt && st != A_FLAG && st != A_FLAGHOLD && st != A_END) begin
                st <= A_OBST; t <= 0; obst_col <= 4'd15; crash <= 1'b0; car_on <= 1'b1;
            end else if (tick_10ms) begin
                case (st)
                    A_OBST: if (t == 14) begin
                                t <= 0;
                                if (obst_col == 4'd9) begin obst_col <= 0; crash <= 1'b1; st <= A_CRASH; end
                                else obst_col <= obst_col - 1'b1;
                            end else t <= t + 1'b1;
                    A_CRASH: if (t == 49) begin
                                t <= 0; crash <= 1'b0; car_on <= 1'b0; blinks <= 0; st <= A_BLINK;
                            end else t <= t + 1'b1;
                    A_BLINK: if (t == 19) begin
                                t <= 0; car_on <= ~car_on;
                                if (blinks == 5) begin car_on <= 1'b1; st <= A_RUN; end
                                else blinks <= blinks + 1'b1;
                            end else t <= t + 1'b1;
                    A_FLAG: if (t == 19) begin
                                t <= 0;
                                if (flag_col == 4'd8) st <= A_FLAGHOLD;
                                else flag_col <= flag_col - 1'b1;
                            end else t <= t + 1'b1;
                    A_FLAGHOLD: if (t == 49) begin st <= A_END; finish_done <= 1'b1; end
                                else t <= t + 1'b1;
                    default: ;
                endcase
            end
        end
    end
endmodule
