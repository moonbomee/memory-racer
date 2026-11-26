module lcd_text (
    input  wire [4:0] pos,
    input  wire [3:0] screen,
    input  wire       blink,
    input  wire [2:0] dip_sel,
    input  wire [1:0] mode,
    input  wire [1:0] level,
    input  wire       bgm_en,
    input  wire       sfx_en,
    input  wire [1:0] rv_mode,
    input  wire [9:0] rv0, rv1, rv2,
    input  wire [1:0] ready_step,
    input  wire       show_hearts,
    input  wire [1:0] hearts,
    input  wire [9:0] score,
    input  wire       lane,
    input  wire [3:0] obst_col,
    input  wire       crash,
    input  wire       car_on,
    input  wire [3:0] flag_col,
    input  wire       res_finish,
    input  wire [1:0] res_rank,
    output reg  [7:0] char_code
);
    wire       r = pos[4];
    wire [3:0] c = pos[3:0];

    localparam [7:0] SP = 8'h20;
    localparam [7:0] CG_CAR_R = 8'd0, CG_CAR_F = 8'd1, CG_LANE_A = 8'd2, CG_LANE_B = 8'd3,
                     CG_CONE = 8'd4, CG_CRASH = 8'd5, CG_FLAG = 8'd6, CG_HEART = 8'd7;

    function [7:0] S;
        input [127:0] s;
        input [3:0]   k;
        S = s[8*(15-k) +: 8];
    endfunction

    function [7:0] DIG;
        input [9:0] v;
        input [1:0] which;
        reg   [9:0] t;
        begin
            t = (v > 10'd999) ? 10'd999 : v;
            case (which)
                2'd2:    DIG = 8'h30 + (t / 100);
                2'd1:    DIG = 8'h30 + ((t / 10) % 10);
                default: DIG = 8'h30 + (t % 10);
            endcase
        end
    endfunction

    function [7:0] MODE_NAME;
        input [1:0] m;
        input [1:0] k;
        case (m)
            2'd0:    MODE_NAME = S("TIME            ", {2'b00, k});
            2'd1:    MODE_NAME = S("LIFE            ", {2'b00, k});
            default: MODE_NAME = S("SIG             ", {2'b00, k});
        endcase
    endfunction

    function [7:0] LEVEL_NAME;
        input [1:0] l;
        input [1:0] k;
        case (l)
            2'd0:    LEVEL_NAME = S("EASY            ", {2'b00, k});
            2'd1:    LEVEL_NAME = S("MID             ", {2'b00, k});
            default: LEVEL_NAME = S("HARD            ", {2'b00, k});
        endcase
    endfunction

    wire [7:0] lane_ch = lane ? CG_LANE_B : CG_LANE_A;

    always @(*) begin
        char_code = SP;
        case (screen)
            4'd0: begin
                char_code = r ? S("3RANK 4SND 5LVL ", c) : S(" 1START   2MODE ", c);
                if (!blink && ((!r && dip_sel == 3'd1 && c >= 1  && c <= 6)  ||
                               (!r && dip_sel == 3'd2 && c >= 10 && c <= 14) ||
                               ( r && dip_sel == 3'd3 && c <= 4)             ||
                               ( r && dip_sel == 3'd4 && c >= 6  && c <= 9)  ||
                               ( r && dip_sel == 3'd5 && c >= 11 && c <= 14)))
                    char_code = SP;
            end

            4'd1: begin
                if (!r) begin
                    if (c >= 5 && c <= 8) char_code = MODE_NAME(mode, c[1:0] - 2'd1);
                    else                  char_code = S("MODE:     #:BACK", c);
                end else begin
                    char_code = S("1TIME 2LIFE 3SIG", c);
                    if (!blink && ((dip_sel == 3'd1 && c <= 4) ||
                                   (dip_sel == 3'd2 && c >= 6 && c <= 10) ||
                                   (dip_sel == 3'd3 && c >= 12)))
                        char_code = SP;
                end
            end

            4'd2: begin
                char_code = r ? S("1TIME 2LIFE 3SIG", c) : S("RANKING  #:BACK ", c);
                if (!blink && r && ((dip_sel == 3'd1 && c <= 4) ||
                                    (dip_sel == 3'd2 && c >= 6 && c <= 10) ||
                                    (dip_sel == 3'd3 && c >= 12)))
                    char_code = SP;
            end

            4'd3: begin
                if (!r) begin
                    if (c <= 3)       char_code = MODE_NAME(rv_mode, c[1:0]);
                    else if (c >= 11 && c <= 13) char_code = DIG(rv0, 2'd2 - (c - 4'd11));
                    else              char_code = S("      1ST       ", c);
                end else begin
                    if (c >= 4 && c <= 6)        char_code = DIG(rv1, 2'd2 - (c - 4'd4));
                    else if (c >= 12 && c <= 14) char_code = DIG(rv2, 2'd2 - (c - 4'd12));
                    else                         char_code = S("2ND     3RD     ", c);
                end
            end

            4'd4: begin
                if (!r) begin
                    char_code = S("1BGM 2SFX #BACK ", c);
                    if (!blink && ((dip_sel == 3'd1 && c <= 3) || (dip_sel == 3'd2 && c >= 5 && c <= 8)))
                        char_code = SP;
                end else if (c >= 4 && c <= 6)   char_code = bgm_en ? S("    ON          ", c) : S("    OFF         ", c);
                else if (c >= 12 && c <= 14) char_code = sfx_en ? S("            ON  ", c) : S("            OFF ", c);
                else                         char_code = S("BGM:    SFX:    ", c);
            end

            4'd5: begin
                if (!r) begin
                    if (c >= 3 && c <= 6) char_code = LEVEL_NAME(level, c[1:0] - 2'd3);
                    else                  char_code = S("LV:       #:BACK", c);
                end else begin
                    char_code = S("1EASY 2MID 3HARD", c);
                    if (!blink && ((dip_sel == 3'd1 && c <= 4) ||
                                   (dip_sel == 3'd2 && c >= 6 && c <= 9) ||
                                   (dip_sel == 3'd3 && c >= 11)))
                        char_code = SP;
                end
            end

            4'd6: char_code = r ? S("CHECK DIP SWITCH", c) : S("INVALID NUMBER! ", c);

            4'd7: begin
                if (!r) char_code = S("  GET READY!    ", c);
                else begin
                    char_code = S("    3  2  1  GO ", c);
                    if ((c >= 7  && ready_step < 2'd1) ||
                        (c >= 10 && ready_step < 2'd2) ||
                        (c >= 13 && ready_step < 2'd3))
                        char_code = SP;
                end
            end

            4'd8: begin
                if (!r) begin
                    if (show_hearts && c < {2'b00, hearts}) char_code = CG_HEART;
                    else if (flag_col != 0 && c == flag_col) char_code = CG_FLAG;
                    else if (c >= 13)                        char_code = DIG(score, 2'd2 - (c - 4'd13));
                    else                                     char_code = lane_ch;
                end else begin
                    if (c == 4'd6)                           char_code = car_on ? CG_CAR_R : SP;
                    else if (c == 4'd7)                      char_code = car_on ? CG_CAR_F : SP;
                    else if (crash && c == 4'd8)             char_code = CG_CRASH;
                    else if (obst_col != 0 && c == obst_col) char_code = CG_CONE;
                    else if (flag_col != 0 && c == flag_col) char_code = CG_FLAG;
                    else                                     char_code = lane_ch;
                end
            end

            4'd9: begin
                if (!r) char_code = res_finish ? S("    FINISH!     ", c) : S("   GAME OVER    ", c);
                else begin
                    if (c >= 6 && c <= 8)                    char_code = DIG(score, 2'd2 - (c - 4'd6));
                    else if (c == 14 && res_rank != 0)       char_code = 8'h30 + res_rank;
                    else if (c >= 10 && res_rank != 0)       char_code = S("SCORE     TOP   ", c);
                    else                                     char_code = S("SCORE           ", c);
                end
            end

            default: char_code = SP;
        endcase
    end
endmodule
