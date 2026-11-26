module rank_store #(
    parameter CLK_HZ = 1_000_000,
    parameter [6:0] DEV_ADDR = 7'h50
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       ins_go,
    input  wire [1:0] ins_mode,
    input  wire [9:0] ins_score,
    output wire [1:0] ins_rank,
    input  wire       clear,
    input  wire [1:0] view_mode,
    output wire [9:0] v0, v1, v2,
    output wire       scl,
    inout  wire       sda,
    output reg        eep_ok
);
    reg [9:0] sc [0:8];

    wire [3:0] ib = ins_mode * 4'd3;
    wire [3:0] vb = view_mode * 4'd3;
    assign v0 = sc[vb];
    assign v1 = sc[vb + 4'd1];
    assign v2 = sc[vb + 4'd2];

    assign ins_rank = (ins_score == 0)               ? 2'd0 :
                      (ins_score > sc[ib])           ? 2'd1 :
                      (ins_score > sc[ib + 4'd1])    ? 2'd2 :
                      (ins_score > sc[ib + 4'd2])    ? 2'd3 : 2'd0;

    localparam integer QT = (CLK_HZ / 200000 > 0) ? CLK_HZ / 200000 : 1;
    localparam C_START = 2'd0, C_WRITE = 2'd1, C_READ = 2'd2, C_STOP = 2'd3;

    reg        scl_r, sda_low;
    assign scl = scl_r;
    assign sda = sda_low ? 1'b0 : 1'bz;

    reg        b_go, b_busy;
    reg [1:0]  b_cmd;
    reg [7:0]  b_tx;
    reg        b_ack_out;
    reg [7:0]  b_rx;
    reg        b_acked;
    reg [15:0] qcnt;
    reg [1:0]  qph;
    reg [3:0]  bitn;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scl_r <= 1'b1; sda_low <= 1'b0; b_busy <= 1'b0;
            qcnt <= 0; qph <= 0; bitn <= 0; b_rx <= 0; b_acked <= 1'b0;
        end else if (!b_busy) begin
            if (b_go) begin b_busy <= 1'b1; qcnt <= 0; qph <= 0; bitn <= 0; end
        end else if (qcnt != QT - 1) begin
            qcnt <= qcnt + 1'b1;
        end else begin
            qcnt <= 0;
            qph  <= qph + 1'b1;
            case (b_cmd)
                C_START: case (qph)
                    2'd0: sda_low <= 1'b0;
                    2'd1: scl_r   <= 1'b1;
                    2'd2: sda_low <= 1'b1;
                    2'd3: begin scl_r <= 1'b0; b_busy <= 1'b0; end
                endcase
                C_STOP: case (qph)
                    2'd0: sda_low <= 1'b1;
                    2'd1: scl_r   <= 1'b1;
                    2'd2: sda_low <= 1'b0;
                    2'd3: b_busy  <= 1'b0;
                endcase
                C_WRITE: case (qph)
                    2'd0: sda_low <= (bitn == 4'd8) ? 1'b0 : ~b_tx[3'd7 - bitn[2:0]];
                    2'd1: scl_r   <= 1'b1;
                    2'd2: if (bitn == 4'd8) b_acked <= ~sda;
                    2'd3: begin
                        scl_r <= 1'b0;
                        if (bitn == 4'd8) begin b_busy <= 1'b0; sda_low <= 1'b0; end
                        bitn <= bitn + 1'b1;
                    end
                endcase
                C_READ: case (qph)
                    2'd0: sda_low <= (bitn == 4'd8) ? b_ack_out : 1'b0;
                    2'd1: scl_r   <= 1'b1;
                    2'd2: if (bitn != 4'd8) b_rx <= {b_rx[6:0], sda};
                    2'd3: begin
                        scl_r <= 1'b0;
                        if (bitn == 4'd8) begin b_busy <= 1'b0; sda_low <= 1'b0; end
                        bitn <= bitn + 1'b1;
                    end
                endcase
            endcase
        end
    end

    localparam Q_IDLE = 3'd0, Q_ISSUE = 3'd1, Q_WAIT = 3'd2, Q_CHECK = 3'd3, Q_HOLD = 3'd4;

    reg [2:0]  qs;
    reg        loading;
    reg [4:0]  p;
    reg        fail;
    reg        pend_save;
    reg [7:0]  rb [0:18];
    reg [19:0] hold;
    reg        dly;

    wire [4:0] last_p = loading ? 5'd25 : 5'd23;
    wire [4:0] j      = loading ? (p - 5'd6) : (p - 5'd4);

    wire [3:0] jn_hi = (j - 5'd1) >> 1;
    wire [3:0] jn_lo = (j - 5'd2) >> 1;
    reg  [7:0] data_byte;
    always @(*) begin
        if (j == 0)    data_byte = 8'hA5;
        else if (j[0]) data_byte = {6'b0, sc[jn_hi][9:8]};
        else           data_byte = sc[jn_lo][7:0];
    end

    reg [1:0] op_cmd;
    reg [7:0] op_tx;
    reg       op_ack;
    always @(*) begin
        op_cmd = C_WRITE; op_tx = 8'h00; op_ack = 1'b0;
        if (p == 0 || (loading && p == 4))  op_cmd = C_START;
        else if (p == last_p)               op_cmd = C_STOP;
        else if (p == 1)                    op_tx  = {DEV_ADDR, 1'b0};
        else if (loading && p == 5)         op_tx  = {DEV_ADDR, 1'b1};
        else if (p == 2 || p == 3)          op_tx  = 8'h00;
        else if (loading)                   begin op_cmd = C_READ; op_ack = (j != 5'd18); end
        else                                op_tx  = data_byte;
    end

    integer m;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (m = 0; m < 9;  m = m + 1) sc[m] <= 0;
            for (m = 0; m < 19; m = m + 1) rb[m] <= 0;
            qs <= Q_ISSUE; loading <= 1'b1; p <= 0; fail <= 1'b0; pend_save <= 1'b0;
            hold <= 0; dly <= 1'b0; eep_ok <= 1'b0;
            b_go <= 1'b0; b_cmd <= C_START; b_tx <= 0; b_ack_out <= 1'b0;
        end else begin
            b_go <= 1'b0;

            if (clear) begin
                for (m = 0; m < 9; m = m + 1) sc[m] <= 0;
                pend_save <= 1'b1;
            end else if (ins_go && ins_rank != 0) begin
                case (ins_rank)
                    2'd1: begin sc[ib + 4'd2] <= sc[ib + 4'd1]; sc[ib + 4'd1] <= sc[ib]; sc[ib] <= ins_score; end
                    2'd2: begin sc[ib + 4'd2] <= sc[ib + 4'd1]; sc[ib + 4'd1] <= ins_score; end
                    default:     sc[ib + 4'd2] <= ins_score;
                endcase
                pend_save <= 1'b1;
            end

            case (qs)
                Q_IDLE: if (pend_save) begin
                    pend_save <= 1'b0; loading <= 1'b0; p <= 0; fail <= 1'b0; qs <= Q_ISSUE;
                end

                Q_ISSUE: begin
                    b_cmd <= op_cmd; b_tx <= op_tx; b_ack_out <= op_ack; b_go <= 1'b1;
                    dly <= 1'b1; qs <= Q_WAIT;
                end

                Q_WAIT: begin
                    dly <= 1'b0;
                    if (!dly && !b_go && !b_busy) qs <= Q_CHECK;
                end

                Q_CHECK: begin
                    if (p == last_p) begin
                        if (loading && !fail && rb[0] == 8'hA5)
                            for (m = 0; m < 9; m = m + 1) sc[m] <= {rb[1 + 2*m][1:0], rb[2 + 2*m]};
                        eep_ok <= !fail;
                        hold <= 0; qs <= Q_HOLD;
                    end else if (op_cmd == C_WRITE && !b_acked) begin
                        fail <= 1'b1; p <= last_p; qs <= Q_ISSUE;
                    end else begin
                        if (op_cmd == C_READ) rb[j] <= b_rx;
                        p <= p + 1'b1; qs <= Q_ISSUE;
                    end
                end

                Q_HOLD: begin
                    if (hold >= CLK_HZ / 100) qs <= Q_IDLE;
                    else hold <= hold + 1'b1;
                end

                default: qs <= Q_IDLE;
            endcase
        end
    end
endmodule
