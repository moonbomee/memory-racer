module memory_racer_top #(
    parameter CLK_HZ = 1_000_000
)(
    input  wire        clk,
    input  wire [11:0] key,
    input  wire [7:0]  dip,
    output wire [7:0]  led,
    output wire [7:0]  seg1,
    output wire [7:0]  seg8_data,
    output wire [7:0]  seg8_com,
    output wire [3:0]  fled_r,
    output wire [3:0]  fled_g,
    output wire [3:0]  fled_b,
    output wire        lcd_e,
    output wire        lcd_rs,
    output wire        lcd_rw,
    output wire [7:0]  lcd_d,
    output wire        piezo,
    output wire        servo,
    output wire        eep_scl,
    inout  wire        eep_sda
);
    reg [3:0] por = 4'd0;
    always @(posedge clk) if (por != 4'hF) por <= por + 1'b1;
    reg rst_s1 = 1'b1, rst = 1'b1;
    always @(posedge clk) begin
        rst_s1 <= (por != 4'hF) | dip[6];
        rst    <= rst_s1;
    end

    wire tick_1ms, tick_10ms, tick_100ms;
    tick_gen #(.CLK_HZ(CLK_HZ)) u_tick (
        .clk(clk), .rst(rst), .tick_1ms(tick_1ms), .tick_10ms(tick_10ms), .tick_100ms(tick_100ms));

    reg [2:0] bl_cnt;
    reg       blink;
    always @(posedge clk or posedge rst) begin
        if (rst) begin bl_cnt <= 0; blink <= 1'b1; end
        else if (tick_100ms) begin
            if (bl_cnt == 3'd4) begin bl_cnt <= 0; blink <= ~blink; end
            else bl_cnt <= bl_cnt + 1'b1;
        end
    end

    wire [11:0] kp;
    btn_trigger #(.N(12)) u_keys (.clk(clk), .rst(rst), .tick_10ms(tick_10ms), .btn_in(key), .pulse(kp));

    wire       k_star   = kp[9];
    wire       k_hash   = kp[11];
    wire       digit_go = |kp[8:0] | kp[10];
    reg  [3:0] digit_val;
    always @(*) begin
        digit_val = 4'd0;
        case (1'b1)
            kp[0]: digit_val = 4'd1;  kp[1]: digit_val = 4'd2;  kp[2]: digit_val = 4'd3;
            kp[3]: digit_val = 4'd4;  kp[4]: digit_val = 4'd5;  kp[5]: digit_val = 4'd6;
            kp[6]: digit_val = 4'd7;  kp[7]: digit_val = 4'd8;  kp[8]: digit_val = 4'd9;
            default: digit_val = 4'd0;
        endcase
    end

    reg [7:0] dip_s1, dip_s2;
    always @(posedge clk) begin dip_s1 <= dip; dip_s2 <= dip_s1; end
    wire [2:0] dip_val = dip_s2[2:0];

    wire [15:0] rnd;
    lfsr16 u_lfsr (.clk(clk), .rst(rst), .q(rnd));

    wire [1:0] mode, level, rv_mode;
    wire       bgm_en, sfx_en, in_game, game_start, rank_clear, click;
    wire [3:0] menu_screen;
    wire       game_done;

    menu_fsm u_menu (
        .clk(clk), .rst(rst), .tick_100ms(tick_100ms),
        .dip_val(dip_val), .dip_clear(dip_s2[7]), .k_star(k_star), .k_hash(k_hash),
        .game_done(game_done),
        .mode(mode), .level(level), .bgm_en(bgm_en), .sfx_en(sfx_en), .rv_mode(rv_mode),
        .screen(menu_screen), .in_game(in_game), .game_start(game_start),
        .rank_clear(rank_clear), .click(click));

    wire [3:0]  game_screen;
    wire [1:0]  ready_step, lives, res_rank, ins_rank;
    wire [9:0]  score;
    wire [4:0]  g_seg1;
    wire [39:0] g_seg8;
    wire [7:0]  g_led;
    wire [2:0]  fc_rgb;
    wire        g_sfx_go, wrong_evt, finish_evt, road_active, res_finish, ins_go;
    wire [3:0]  g_sfx_id;
    wire        anim_busy, finish_done;

    game_fsm u_game (
        .clk(clk), .rst(rst), .tick_10ms(tick_10ms), .tick_100ms(tick_100ms),
        .start(game_start), .mode(mode), .level(level),
        .digit_go(digit_go && in_game), .digit_val(digit_val),
        .k_star(k_star && in_game), .k_hash(k_hash && in_game),
        .rnd(rnd), .anim_busy(anim_busy), .finish_done(finish_done), .ins_rank(ins_rank),
        .screen(game_screen), .ready_step(ready_step), .score(score), .lives(lives),
        .seg1_code(g_seg1), .seg8_codes(g_seg8), .led_bar(g_led), .fc_rgb(fc_rgb),
        .sfx_go(g_sfx_go), .sfx_id(g_sfx_id), .wrong_evt(wrong_evt), .finish_evt(finish_evt),
        .road_active(road_active), .res_finish(res_finish), .res_rank(res_rank),
        .ins_go(ins_go), .done(game_done));

    wire       lane, crash, car_on;
    wire [3:0] obst_col, flag_col;
    road_anim u_anim (
        .clk(clk), .rst(rst), .tick_10ms(tick_10ms), .active(in_game && road_active),
        .wrong_evt(wrong_evt), .finish_evt(finish_evt),
        .lane(lane), .obst_col(obst_col), .crash(crash), .car_on(car_on), .flag_col(flag_col),
        .busy(anim_busy), .finish_done(finish_done));

    wire [9:0] rv0, rv1, rv2;
    wire       eep_ok;
    rank_store #(.CLK_HZ(CLK_HZ)) u_rank (
        .clk(clk), .rst(rst),
        .ins_go(ins_go), .ins_mode(mode), .ins_score(score), .ins_rank(ins_rank),
        .clear(rank_clear), .view_mode(rv_mode), .v0(rv0), .v1(rv1), .v2(rv2),
        .scl(eep_scl), .sda(eep_sda), .eep_ok(eep_ok));

    wire [4:0] lcd_pos;
    wire [7:0] lcd_char;
    lcd_text u_text (
        .pos(lcd_pos), .screen(in_game ? game_screen : menu_screen), .blink(blink),
        .mode(mode), .level(level), .bgm_en(bgm_en), .sfx_en(sfx_en),
        .rv_mode(rv_mode), .rv0(rv0), .rv1(rv1), .rv2(rv2),
        .ready_step(ready_step),
        .show_hearts(mode != 2'd0), .hearts(lives), .score(score),
        .lane(lane), .obst_col(obst_col), .crash(crash), .car_on(car_on), .flag_col(flag_col),
        .res_finish(res_finish), .res_rank(res_rank),
        .char_code(lcd_char));

    lcd_ctrl #(.CLK_HZ(CLK_HZ)) u_lcd (
        .clk(clk), .rst(rst), .pos(lcd_pos), .char_code(lcd_char),
        .lcd_e(lcd_e), .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_data(lcd_d));

    wire [4:0] seg1_code = in_game ? g_seg1 : {2'b00, dip_val};
    seg7_dec u_seg1 (.code(seg1_code), .seg(seg1));

    seg8_scan u_seg8 (
        .clk(clk), .rst(rst), .tick_1ms(tick_1ms),
        .codes(in_game ? g_seg8 : {8{5'd10}}),
        .seg_data(seg8_data), .seg_com(seg8_com));

    assign led    = in_game ? g_led : 8'h00;
    assign fled_r = {4{in_game & fc_rgb[2]}};
    assign fled_g = {4{in_game & fc_rgb[1]}};
    assign fled_b = {4{in_game & fc_rgb[0]}};

    localparam [11:0] SERVO_0 = 12'd700, SERVO_60 = 12'd1233, SERVO_120 = 12'd1767, SERVO_180 = 12'd2300;
    reg [11:0] servo_us;
    always @(*) begin
        if (in_game && mode != 2'd0) begin
            case (lives)
                2'd3:    servo_us = SERVO_180;
                2'd2:    servo_us = SERVO_120;
                2'd1:    servo_us = SERVO_60;
                default: servo_us = SERVO_0;
            endcase
        end else servo_us = SERVO_180;
    end
    servo_pwm #(.CLK_HZ(CLK_HZ)) u_servo (.clk(clk), .rst(rst), .pulse_us(servo_us), .servo(servo));

    sound #(.CLK_HZ(CLK_HZ)) u_sound (
        .clk(clk), .rst(rst), .tick_10ms(tick_10ms),
        .sfx_go(g_sfx_go | click), .sfx_id(g_sfx_go ? g_sfx_id : 4'd0),
        .sfx_en(sfx_en), .bgm_en(bgm_en), .piezo(piezo));
endmodule
