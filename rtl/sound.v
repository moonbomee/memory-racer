module sound #(
    parameter CLK_HZ = 1_000_000
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_10ms,
    input  wire       sfx_go,
    input  wire [3:0] sfx_id,
    input  wire       sfx_en,
    input  wire       bgm_en,
    output reg        piezo
);
    function [19:0] HALF;
        input [3:0] nt;
        case (nt)
            4'd1:  HALF = CLK_HZ / 523;
            4'd2:  HALF = CLK_HZ / 587;
            4'd3:  HALF = CLK_HZ / 659;
            4'd4:  HALF = CLK_HZ / 698;
            4'd5:  HALF = CLK_HZ / 784;
            4'd6:  HALF = CLK_HZ / 880;
            4'd7:  HALF = CLK_HZ / 988;
            4'd8:  HALF = CLK_HZ / 1047;
            4'd9:  HALF = CLK_HZ / 1175;
            4'd10: HALF = CLK_HZ / 1319;
            4'd11: HALF = CLK_HZ / 1397;
            4'd12: HALF = CLK_HZ / 1568;
            4'd13: HALF = CLK_HZ / 1760;
            4'd14: HALF = CLK_HZ / 2093;
            default: HALF = 0;
        endcase
    endfunction

    localparam [3:0] END = 4'd15, R = 4'd0;
    function [9:0] SFX_ROM;
        input [5:0] a;
        case (a)
            6'd0:  SFX_ROM = {4'd12, 6'd3};   6'd1:  SFX_ROM = {END, 6'd0};
            6'd2:  SFX_ROM = {4'd8, 6'd15};   6'd3:  SFX_ROM = {END, 6'd0};
            6'd4:  SFX_ROM = {4'd14, 6'd40};  6'd5:  SFX_ROM = {END, 6'd0};
            6'd6:  SFX_ROM = {4'd10, 6'd8};   6'd7:  SFX_ROM = {4'd12, 6'd8};
            6'd8:  SFX_ROM = {4'd14, 6'd15};  6'd9:  SFX_ROM = {END, 6'd0};
            6'd10: SFX_ROM = {4'd1, 6'd15};   6'd11: SFX_ROM = {R, 6'd4};
            6'd12: SFX_ROM = {4'd1, 6'd25};   6'd13: SFX_ROM = {END, 6'd0};
            6'd14: SFX_ROM = {4'd13, 6'd8};   6'd15: SFX_ROM = {R, 6'd5};
            6'd16: SFX_ROM = {4'd13, 6'd8};   6'd17: SFX_ROM = {END, 6'd0};
            6'd18: SFX_ROM = {4'd8, 6'd10};   6'd19: SFX_ROM = {4'd10, 6'd10};
            6'd20: SFX_ROM = {4'd12, 6'd10};  6'd21: SFX_ROM = {4'd14, 6'd30};
            6'd22: SFX_ROM = {END, 6'd0};
            6'd23: SFX_ROM = {4'd5, 6'd15};   6'd24: SFX_ROM = {4'd3, 6'd15};
            6'd25: SFX_ROM = {4'd1, 6'd40};   6'd26: SFX_ROM = {END, 6'd0};
            6'd27: SFX_ROM = {4'd8, 6'd8};    6'd28: SFX_ROM = {4'd10, 6'd8};
            6'd29: SFX_ROM = {4'd12, 6'd8};   6'd30: SFX_ROM = {4'd14, 6'd8};
            6'd31: SFX_ROM = {4'd12, 6'd8};   6'd32: SFX_ROM = {4'd14, 6'd30};
            6'd33: SFX_ROM = {END, 6'd0};
            default: SFX_ROM = {END, 6'd0};
        endcase
    endfunction

    function [5:0] SFX_START;
        input [3:0] id;
        case (id)
            4'd0: SFX_START = 6'd0;   4'd1: SFX_START = 6'd2;   4'd2: SFX_START = 6'd4;
            4'd3: SFX_START = 6'd6;   4'd4: SFX_START = 6'd10;  4'd5: SFX_START = 6'd14;
            4'd6: SFX_START = 6'd18;  4'd7: SFX_START = 6'd23;  default: SFX_START = 6'd27;
        endcase
    endfunction

    function [3:0] BGM_ROM;
        input [4:0] a;
        case (a)
            5'd0: BGM_ROM = 4'd8;   5'd1: BGM_ROM = 4'd10;  5'd2: BGM_ROM = 4'd12;  5'd3: BGM_ROM = 4'd10;
            5'd4: BGM_ROM = 4'd11;  5'd5: BGM_ROM = 4'd13;  5'd6: BGM_ROM = 4'd12;  5'd7: BGM_ROM = 4'd0;
            5'd8: BGM_ROM = 4'd10;  5'd9: BGM_ROM = 4'd12;  5'd10: BGM_ROM = 4'd14; 5'd11: BGM_ROM = 4'd12;
            5'd12: BGM_ROM = 4'd11; 5'd13: BGM_ROM = 4'd10; 5'd14: BGM_ROM = 4'd9;  5'd15: BGM_ROM = 4'd0;
            5'd16: BGM_ROM = 4'd8;  5'd17: BGM_ROM = 4'd10; 5'd18: BGM_ROM = 4'd12; 5'd19: BGM_ROM = 4'd10;
            5'd20: BGM_ROM = 4'd11; 5'd21: BGM_ROM = 4'd13; 5'd22: BGM_ROM = 4'd12; 5'd23: BGM_ROM = 4'd10;
            5'd24: BGM_ROM = 4'd9;  5'd25: BGM_ROM = 4'd11; 5'd26: BGM_ROM = 4'd10; 5'd27: BGM_ROM = 4'd9;
            5'd28: BGM_ROM = 4'd8;  5'd29: BGM_ROM = 4'd0;  5'd30: BGM_ROM = 4'd8;  default: BGM_ROM = 4'd0;
        endcase
    endfunction

    reg       sfx_on;
    reg [5:0] sfx_ptr, sfx_left;
    reg [3:0] sfx_note;
    reg [4:0] bgm_ptr;
    reg [3:0] bgm_t;

    wire [9:0] ent = SFX_ROM(sfx_ptr);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sfx_on <= 1'b0; sfx_ptr <= 0; sfx_left <= 0; sfx_note <= 0;
            bgm_ptr <= 0; bgm_t <= 0;
        end else begin
            if (sfx_go && (sfx_en || sfx_id == 4'd5)) begin
                sfx_on <= 1'b1; sfx_ptr <= SFX_START(sfx_id); sfx_left <= 0; sfx_note <= 0;
            end else if (tick_10ms && sfx_on) begin
                if (sfx_left == 0) begin
                    if (ent[9:6] == END) begin sfx_on <= 1'b0; sfx_note <= 0; end
                    else begin
                        sfx_note <= ent[9:6];
                        sfx_left <= ent[5:0] - 1'b1;
                        sfx_ptr  <= sfx_ptr + 1'b1;
                    end
                end else sfx_left <= sfx_left - 1'b1;
            end

            if (tick_10ms && bgm_en && !sfx_on) begin
                if (bgm_t == 4'd14) begin bgm_t <= 0; bgm_ptr <= bgm_ptr + 1'b1; end
                else bgm_t <= bgm_t + 1'b1;
            end
        end
    end

    wire [3:0]  note_now = sfx_on ? sfx_note : (bgm_en ? BGM_ROM(bgm_ptr) : 4'd0);
    wire [19:0] half     = HALF(note_now);
    wire        gap      = !sfx_on && (bgm_t >= 4'd13);
    reg  [19:0] tcnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin tcnt <= 0; piezo <= 1'b0; end
        else if (note_now == 0 || half == 0 || gap) begin tcnt <= 0; piezo <= 1'b0; end
        else if (tcnt >= half - 1) begin tcnt <= 0; piezo <= ~piezo; end
        else tcnt <= tcnt + 1'b1;
    end
endmodule
