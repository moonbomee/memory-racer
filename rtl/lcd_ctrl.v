module lcd_ctrl #(
    parameter CLK_HZ = 1_000_000
)(
    input  wire       clk,
    input  wire       rst,
    output wire [4:0] pos,
    input  wire [7:0] char_code,
    output reg        lcd_e,
    output reg        lcd_rs,
    output wire       lcd_rw,
    output reg  [7:0] lcd_data
);
    assign lcd_rw = 1'b0;

    localparam integer TPMS = (CLK_HZ / 1000 > 0) ? CLK_HZ / 1000 : 1;
    function [31:0] T;
        input [31:0] us;
        T = (us * TPMS) / 1000 + 1;
    endfunction
    localparam [31:0] E_TICKS = T(1);

    localparam ST_PWR = 3'd0, ST_INIT = 3'd1, ST_CGCMD = 3'd2, ST_CG = 3'd3,
               ST_ROWCMD = 3'd4, ST_ROW = 3'd5;

    reg [2:0]  st;
    reg [5:0]  idx;
    reg        row;
    reg [1:0]  ph;
    reg [31:0] cnt;
    reg [31:0] wait_ticks;

    assign pos = {row, idx[3:0]};

    function [4:0] cg_row;
        input [5:0] a;
        begin
            case (a)
                6'd0:  cg_row = 5'b00000; 6'd1:  cg_row = 5'b00011; 6'd2:  cg_row = 5'b00100; 6'd3:  cg_row = 5'b01111;
                6'd4:  cg_row = 5'b11111; 6'd5:  cg_row = 5'b11111; 6'd6:  cg_row = 5'b01100; 6'd7:  cg_row = 5'b01100;
                6'd8:  cg_row = 5'b00000; 6'd9:  cg_row = 5'b11100; 6'd10: cg_row = 5'b10010; 6'd11: cg_row = 5'b11111;
                6'd12: cg_row = 5'b11111; 6'd13: cg_row = 5'b11111; 6'd14: cg_row = 5'b00110; 6'd15: cg_row = 5'b00110;
                6'd23: cg_row = 5'b11100;
                6'd31: cg_row = 5'b00111;
                6'd32: cg_row = 5'b00000; 6'd33: cg_row = 5'b00100; 6'd34: cg_row = 5'b00100; 6'd35: cg_row = 5'b01110;
                6'd36: cg_row = 5'b01010; 6'd37: cg_row = 5'b01110; 6'd38: cg_row = 5'b11111; 6'd39: cg_row = 5'b00000;
                6'd40: cg_row = 5'b10001; 6'd41: cg_row = 5'b01010; 6'd42: cg_row = 5'b10101; 6'd43: cg_row = 5'b01110;
                6'd44: cg_row = 5'b11111; 6'd45: cg_row = 5'b01110; 6'd46: cg_row = 5'b10101; 6'd47: cg_row = 5'b01010;
                6'd48: cg_row = 5'b10101; 6'd49: cg_row = 5'b01010; 6'd50: cg_row = 5'b10101; 6'd51: cg_row = 5'b01010;
                6'd52: cg_row = 5'b10101; 6'd53: cg_row = 5'b01010; 6'd54: cg_row = 5'b10101; 6'd55: cg_row = 5'b01010;
                6'd56: cg_row = 5'b00000; 6'd57: cg_row = 5'b01010; 6'd58: cg_row = 5'b11111; 6'd59: cg_row = 5'b11111;
                6'd60: cg_row = 5'b01110; 6'd61: cg_row = 5'b00100; 6'd62: cg_row = 5'b00000; 6'd63: cg_row = 5'b00000;
                default: cg_row = 5'b00000;
            endcase
        end
    endfunction

    reg        op_rs;
    reg [7:0]  op_data;
    reg [31:0] op_wait;
    always @(*) begin
        op_rs = 1'b0; op_data = 8'h00; op_wait = T(60);
        case (st)
            ST_INIT: case (idx)
                6'd0: begin op_data = 8'h38; op_wait = T(5000); end
                6'd1: begin op_data = 8'h38; op_wait = T(200);  end
                6'd2: begin op_data = 8'h38; op_wait = T(200);  end
                6'd3: begin op_data = 8'h38; op_wait = T(100);  end
                6'd4: begin op_data = 8'h0C; op_wait = T(100);  end
                6'd5: begin op_data = 8'h01; op_wait = T(2000); end
                default: begin op_data = 8'h06; op_wait = T(100); end
            endcase
            ST_CGCMD:  begin op_data = 8'h40; op_wait = T(100); end
            ST_CG:     begin op_rs = 1'b1; op_data = {3'b000, cg_row(idx)}; end
            ST_ROWCMD: begin op_data = row ? 8'hC0 : 8'h80; end
            ST_ROW:    begin op_rs = 1'b1; op_data = char_code; end
            default: ;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            st <= ST_PWR; idx <= 0; row <= 1'b0; ph <= 2'd0;
            cnt <= T(50000); wait_ticks <= 0;
            lcd_e <= 1'b0; lcd_rs <= 1'b0; lcd_data <= 8'h00;
        end else begin
            case (ph)
                2'd0: begin
                    if (st == ST_PWR) begin
                        if (cnt != 0) cnt <= cnt - 1'b1;
                        else begin st <= ST_INIT; idx <= 0; end
                    end else begin
                        lcd_rs     <= op_rs;
                        lcd_data   <= op_data;
                        wait_ticks <= op_wait;
                        ph         <= 2'd1;
                    end
                end
                2'd1: begin lcd_e <= 1'b1; cnt <= E_TICKS; ph <= 2'd2; end
                2'd2: begin
                    if (cnt != 0) cnt <= cnt - 1'b1;
                    else begin lcd_e <= 1'b0; cnt <= wait_ticks; ph <= 2'd3; end
                end
                2'd3: begin
                    if (cnt != 0) cnt <= cnt - 1'b1;
                    else begin
                        ph <= 2'd0;
                        case (st)
                            ST_INIT:   if (idx == 6)  begin st <= ST_CGCMD; idx <= 0; end else idx <= idx + 1'b1;
                            ST_CGCMD:  begin st <= ST_CG; idx <= 0; end
                            ST_CG:     if (idx == 63) begin st <= ST_ROWCMD; row <= 1'b0; idx <= 0; end else idx <= idx + 1'b1;
                            ST_ROWCMD: begin st <= ST_ROW; idx <= 0; end
                            ST_ROW:    if (idx == 15) begin st <= ST_ROWCMD; row <= ~row; idx <= 0; end else idx <= idx + 1'b1;
                            default: ;
                        endcase
                    end
                end
            endcase
        end
    end
endmodule
