module menu_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_100ms,
    input  wire [2:0] dip_val,
    input  wire       dip_clear,
    input  wire       k_star,
    input  wire       k_hash,
    input  wire       game_done,
    output reg  [1:0] mode,
    output reg  [1:0] level,
    output reg        bgm_en,
    output reg        sfx_en,
    output reg  [1:0] rv_mode,
    output reg  [3:0] screen,
    output wire       in_game,
    output reg        game_start,
    output reg        rank_clear,
    output reg        click
);
    localparam M_MAIN = 3'd0, M_MODE = 3'd1, M_RANKSEL = 3'd2, M_RANKVIEW = 3'd3,
               M_SOUND = 3'd4, M_LEVEL = 3'd5, M_INVALID = 3'd6, M_GAME = 3'd7;

    reg [2:0] st, ret;
    reg [4:0] inv_t;

    assign in_game = (st == M_GAME);

    always @(*) begin
        case (st)
            M_MAIN:     screen = 4'd0;
            M_MODE:     screen = 4'd1;
            M_RANKSEL:  screen = 4'd2;
            M_RANKVIEW: screen = 4'd3;
            M_SOUND:    screen = 4'd4;
            M_LEVEL:    screen = 4'd5;
            M_INVALID:  screen = 4'd6;
            default:    screen = 4'd0;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            st <= M_MAIN; ret <= M_MAIN; inv_t <= 0;
            mode <= 2'd0; level <= 2'd1; bgm_en <= 1'b1; sfx_en <= 1'b1; rv_mode <= 2'd0;
            game_start <= 1'b0; rank_clear <= 1'b0; click <= 1'b0;
        end else begin
            game_start <= 1'b0;
            rank_clear <= 1'b0;
            click      <= (k_star || k_hash) && st != M_GAME;

            case (st)
                M_MAIN: if (k_star) begin
                    case (dip_val)
                        3'd1: begin st <= M_GAME; game_start <= 1'b1; end
                        3'd2: st <= M_MODE;
                        3'd3: st <= M_RANKSEL;
                        3'd4: st <= M_SOUND;
                        3'd5: st <= M_LEVEL;
                        default: begin ret <= M_MAIN; st <= M_INVALID; inv_t <= 0; end
                    endcase
                end

                M_MODE: if (k_hash) st <= M_MAIN;
                    else if (k_star) begin
                        if (dip_val >= 3'd1 && dip_val <= 3'd3) mode <= dip_val[1:0] - 2'd1;
                        else begin ret <= M_MODE; st <= M_INVALID; inv_t <= 0; end
                    end

                M_RANKSEL: if (k_hash) st <= M_MAIN;
                    else if (k_star) begin
                        if (dip_val >= 3'd1 && dip_val <= 3'd3) begin rv_mode <= dip_val[1:0] - 2'd1; st <= M_RANKVIEW; end
                        else begin ret <= M_RANKSEL; st <= M_INVALID; inv_t <= 0; end
                    end

                M_RANKVIEW: if (k_hash) st <= M_RANKSEL;
                    else if (k_star && dip_clear) rank_clear <= 1'b1;

                M_SOUND: if (k_hash) st <= M_MAIN;
                    else if (k_star) begin
                        if (dip_val == 3'd1)      bgm_en <= ~bgm_en;
                        else if (dip_val == 3'd2) sfx_en <= ~sfx_en;
                        else begin ret <= M_SOUND; st <= M_INVALID; inv_t <= 0; end
                    end

                M_LEVEL: if (k_hash) st <= M_MAIN;
                    else if (k_star) begin
                        if (dip_val >= 3'd1 && dip_val <= 3'd3) level <= dip_val[1:0] - 2'd1;
                        else begin ret <= M_LEVEL; st <= M_INVALID; inv_t <= 0; end
                    end

                M_INVALID: begin
                    if (k_star || k_hash || inv_t == 5'd15) st <= ret;
                    else if (tick_100ms) inv_t <= inv_t + 1'b1;
                end

                M_GAME: if (game_done) st <= M_MAIN;

                default: st <= M_MAIN;
            endcase
        end
    end
endmodule
