module game_fsm (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_10ms,
    input  wire        tick_100ms,
    input  wire        start,
    input  wire [1:0]  mode,
    input  wire [1:0]  level,
    input  wire        digit_go,
    input  wire [3:0]  digit_val,
    input  wire        k_star,
    input  wire        k_hash,
    input  wire [15:0] rnd,
    input  wire        anim_busy,
    input  wire        finish_done,
    input  wire [1:0]  ins_rank,
    output reg  [3:0]  screen,
    output reg  [1:0]  ready_step,
    output reg  [9:0]  score,
    output reg  [1:0]  lives,
    output reg  [4:0]  seg1_code,
    output reg  [39:0] seg8_codes,
    output reg  [7:0]  led_bar,
    output reg  [2:0]  fc_rgb,
    output reg         sfx_go,
    output reg  [3:0]  sfx_id,
    output reg         wrong_evt,
    output reg         finish_evt,
    output wire        road_active,
    output reg         res_finish,
    output reg  [1:0]  res_rank,
    output reg         ins_go,
    output reg         done
);
    localparam SFX_CLICK = 4'd0, SFX_BEEP = 4'd1, SFX_GO = 4'd2, SFX_OK = 4'd3, SFX_NG = 4'd4,
               SFX_SIGNAL = 4'd5, SFX_FINISH = 4'd6, SFX_OVER = 4'd7, SFX_RECORD = 4'd8;

    localparam G_IDLE = 4'd0, G_READY = 4'd1, G_GEN = 4'd2, G_CUE = 4'd3, G_SHOW = 4'd4,
               G_INPUT = 4'd5, G_FEED = 4'd6, G_ENDFIN = 4'd7, G_ENDOVER = 4'd8, G_RESULT = 4'd9;

    localparam [4:0] C_BLANK = 5'd10, C_UNDER = 5'd11;

    reg [3:0] st;
    reg [7:0] t;
    reg [7:0] q;
    reg [3:0] len;
    reg [3:0] k;
    reg       sh_on;
    reg [3:0] cnt;
    reg       rev;
    reg       last_ok;
    reg [9:0] time_left;
    reg [6:0] inp_left;
    reg [2:0] gi, gsub;

    reg [3:0] pd [0:7];
    reg [3:0] id [0:7];

    assign road_active = (st >= G_GEN && st <= G_ENDOVER);

    integer i;
    reg match;
    always @(*) begin
        match = (cnt == len);
        for (i = 0; i < 8; i = i + 1)
            if (i < len)
                if (id[i] != (rev ? pd[len - 1 - i] : pd[i])) match = 1'b0;
    end

    wire [7:0] on_time = (level == 2'd0) ? 8'd100 : (level == 2'd1) ? 8'd70 : 8'd40;
    wire [3:0] pts_base = (level == 2'd0) ? 4'd1 : (level == 2'd1) ? 4'd3 : 4'd5;
    wire [4:0] pts      = rev ? {pts_base, 1'b0} : {1'b0, pts_base};
    wire [10:0] score_sum = score + pts;

    wire [7:0] q_next   = q + 1'b1;
    wire [7:0] q_plus2  = q + 8'd2;
    wire [3:0] len_of_q = (q >= 8'd10) ? 4'd8 : 4'd2 + q_plus2[4:1];

    wire playing = (st >= G_GEN && st <= G_INPUT);
    wire time_up = (mode == 2'd0) && (time_left == 0);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            st <= G_IDLE; t <= 0; q <= 0; len <= 4'd2; k <= 0; sh_on <= 1'b0; cnt <= 0;
            rev <= 1'b0; last_ok <= 1'b0; time_left <= 10'd800; inp_left <= 7'd80;
            gi <= 0; gsub <= 0; ready_step <= 0; score <= 0; lives <= 2'd3;
            sfx_go <= 1'b0; sfx_id <= 0; wrong_evt <= 1'b0; finish_evt <= 1'b0;
            res_finish <= 1'b0; res_rank <= 0; ins_go <= 1'b0; done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin pd[i] <= 0; id[i] <= 0; end
        end else begin
            sfx_go     <= 1'b0;
            wrong_evt  <= 1'b0;
            finish_evt <= 1'b0;
            ins_go     <= 1'b0;
            done       <= 1'b0;

            if (mode == 2'd0 && playing && tick_100ms && time_left != 0)
                time_left <= time_left - 1'b1;

            case (st)
                G_IDLE: if (start) begin
                    st <= G_READY; t <= 0; ready_step <= 0;
                    score <= 0; lives <= 2'd3; q <= 0; time_left <= 10'd800;
                    sfx_go <= 1'b1; sfx_id <= SFX_BEEP;
                end

                G_READY: if (tick_10ms) begin
                    if (t == 99) begin
                        t <= 0;
                        if (ready_step == 2'd3) begin st <= G_GEN; gi <= 0; gsub <= 0; len <= 4'd2; end
                        else begin
                            ready_step <= ready_step + 1'b1;
                            sfx_go <= 1'b1;
                            sfx_id <= (ready_step == 2'd2) ? SFX_GO : SFX_BEEP;
                        end
                    end else t <= t + 1'b1;
                end

                G_GEN: begin
                    gsub <= gsub + 1'b1;
                    if (gsub == 3'd7) begin
                        pd[gi] <= rnd[7:0] % 10;
                        if (gi == 3'd7) begin
                            rev <= (mode == 2'd2) ? (rnd[15:14] == 2'b11) : 1'b0;
                            st <= G_CUE; t <= 0;
                        end
                        gi <= gi + 1'b1;
                    end
                end

                G_CUE: begin
                    if (t == 0 && tick_10ms && mode == 2'd2 && rev) begin
                        sfx_go <= 1'b1; sfx_id <= SFX_SIGNAL;
                    end
                    if (time_up) begin st <= G_ENDFIN; finish_evt <= 1'b1; sfx_go <= 1'b1; sfx_id <= SFX_FINISH; res_finish <= 1'b1; end
                    else if (tick_10ms) begin
                        if (t == ((mode == 2'd2) ? 8'd59 : 8'd29)) begin
                            st <= G_SHOW; t <= 0; k <= 0; sh_on <= 1'b1;
                        end else t <= t + 1'b1;
                    end
                end

                G_SHOW: begin
                    if (time_up) begin st <= G_ENDFIN; finish_evt <= 1'b1; sfx_go <= 1'b1; sfx_id <= SFX_FINISH; res_finish <= 1'b1; end
                    else if (tick_10ms) begin
                        if (sh_on) begin
                            if (t == on_time - 1'b1) begin t <= 0; sh_on <= 1'b0; end
                            else t <= t + 1'b1;
                        end else begin
                            if (t == 8'd14) begin
                                t <= 0;
                                if (k == len - 1'b1) begin st <= G_INPUT; cnt <= 0; inp_left <= 7'd80; end
                                else begin k <= k + 1'b1; sh_on <= 1'b1; end
                            end else t <= t + 1'b1;
                        end
                    end
                end

                G_INPUT: begin
                    if (time_up) begin st <= G_ENDFIN; finish_evt <= 1'b1; sfx_go <= 1'b1; sfx_id <= SFX_FINISH; res_finish <= 1'b1; end
                    else if (k_star || (mode != 2'd0 && inp_left == 0)) begin
                        st <= G_FEED; t <= 0;
                        sfx_go <= 1'b1;
                        if (k_star && match) begin
                            last_ok <= 1'b1;
                            score   <= (score_sum > 11'd999) ? 10'd999 : score_sum[9:0];
                            sfx_id  <= SFX_OK;
                        end else begin
                            last_ok   <= 1'b0;
                            wrong_evt <= 1'b1;
                            sfx_id    <= SFX_NG;
                            if (mode == 2'd0)
                                time_left <= (time_left > 10'd100) ? time_left - 10'd100 : 10'd0;
                            else if (lives != 0)
                                lives <= lives - 1'b1;
                        end
                    end else begin
                        if (digit_go && cnt < len) begin
                            id[cnt] <= digit_val; cnt <= cnt + 1'b1;
                            sfx_go <= 1'b1; sfx_id <= SFX_CLICK;
                        end else if (k_hash && cnt != 0) begin
                            cnt <= cnt - 1'b1;
                            sfx_go <= 1'b1; sfx_id <= SFX_CLICK;
                        end
                        if (mode != 2'd0 && tick_100ms && inp_left != 0)
                            inp_left <= inp_left - 1'b1;
                    end
                end

                G_FEED: if (tick_10ms) begin
                    if (!last_ok && anim_busy) t <= 0;
                    else if (t == (last_ok ? 8'd119 : 8'd59)) begin
                        t <= 0;
                        if (mode == 2'd0 && time_left == 0) begin
                            st <= G_ENDFIN; finish_evt <= 1'b1; sfx_go <= 1'b1; sfx_id <= SFX_FINISH; res_finish <= 1'b1;
                        end else if (mode != 2'd0 && lives == 0) begin
                            st <= G_ENDOVER; res_finish <= 1'b0;
                        end else begin
                            q <= (q == 8'd255) ? q : q_next;
                            len <= len_of_q;
                            st <= G_GEN; gi <= 0; gsub <= 0;
                        end
                    end else t <= t + 1'b1;
                end

                G_ENDFIN: if (finish_done) begin
                    st <= G_RESULT; t <= 0; ins_go <= 1'b1; res_rank <= ins_rank;
                    if (ins_rank != 0) begin sfx_go <= 1'b1; sfx_id <= SFX_RECORD; end
                end

                G_ENDOVER: if (!anim_busy) begin
                    st <= G_RESULT; t <= 0; ins_go <= 1'b1; res_rank <= ins_rank;
                    sfx_go <= 1'b1; sfx_id <= (ins_rank != 0) ? SFX_RECORD : SFX_OVER;
                end

                G_RESULT: begin
                    if (t != 8'd100) begin if (tick_10ms) t <= t + 1'b1; end
                    else if (k_star || k_hash) begin st <= G_IDLE; done <= 1'b1; end
                end

                default: st <= G_IDLE;
            endcase
        end
    end

    function [7:0] BAR;
        input [3:0] n;
        BAR = (n >= 4'd8) ? 8'hFF : ((8'h01 << n) - 1'b1);
    endfunction

    wire [3:0] time_leds = (time_left + 10'd99) / 10'd100;
    wire [3:0] inp_leds  = (inp_left + 7'd9) / 7'd10;

    integer j;
    always @(*) begin
        case (st)
            G_READY:  screen = 4'd7;
            G_RESULT: screen = 4'd9;
            default:  screen = 4'd8;
        endcase

        seg1_code = (st == G_SHOW && sh_on) ? {1'b0, pd[k]} : C_BLANK;
        if (st == G_READY) seg1_code = {3'b000, 2'd3 - ready_step};
        if (st == G_READY && ready_step == 2'd3) seg1_code = C_BLANK;

        seg8_codes = {8{C_BLANK}};
        if (st == G_INPUT || st == G_FEED) begin
            for (j = 0; j < 8; j = j + 1)
                if (j < cnt)      seg8_codes[j*5 +: 5] = {1'b0, id[j]};
                else if (j < len) seg8_codes[j*5 +: 5] = C_UNDER;
        end else if (st == G_RESULT) begin
            seg8_codes[25 +: 5] = (score / 100);
            seg8_codes[30 +: 5] = ((score / 10) % 10);
            seg8_codes[35 +: 5] = (score % 10);
        end

        led_bar = 8'h00;
        if (st >= G_GEN && st <= G_ENDOVER) begin
            if (mode == 2'd0)        led_bar = BAR(time_leds);
            else if (st == G_INPUT)  led_bar = BAR(inp_leds);
            else                     led_bar = 8'hFF;
        end

        fc_rgb = 3'b000;
        if (mode == 2'd2 && (st == G_CUE || st == G_SHOW || st == G_INPUT))
            fc_rgb = rev ? 3'b100 : 3'b010;
        if (st == G_FEED && t < 8'd50)
            fc_rgb = last_ok ? 3'b010 : 3'b100;
    end
endmodule
