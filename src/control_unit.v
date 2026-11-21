module control_unit (
    input wire       clk,
    input wire       reset,
    input wire       cpu_ce,

    input wire [7:0] ir,
    input wire       zero,
    input wire       carry,

    output reg       pc_inc,
    output reg       pc_load,

    output reg       mar_we,
    output reg       mar_sel,
    output reg       mdr_we,
    output reg       ir_we,
    output reg       iar_we,

    output reg       operand1_we,
    output reg       operand2_we,

    output reg       gpr_we,
    output reg       flag_we,
    output reg       ram_we,
    output reg       out_we,

    output reg [1:0] wb_sel,

    output wire [2:0] alu_opcodes,
    output wire [3:0] state_out
);

    localparam S0  = 4'd0;
    localparam S1  = 4'd1;
    localparam S2  = 4'd2;
    localparam S3  = 4'd3;
    localparam S4  = 4'd4;
    localparam S5  = 4'd5;
    localparam S6  = 4'd6;
    localparam S7  = 4'd7;
    localparam S8  = 4'd8;
    localparam S9  = 4'd9;
    localparam S10 = 4'd10;
    localparam S11 = 4'd11;
    localparam S12 = 4'd12;
    localparam S13 = 4'd13;
    localparam S14 = 4'd14;
    localparam S15 = 4'd15;

    reg [3:0] state;
    reg [3:0] next_state;

    assign state_out   = state;
    assign alu_opcodes = ir[6:4];

    wire [3:0] opcode;
    assign opcode = ir[7:4];

    wire alu_inst;
    assign alu_inst =
        (opcode >= 4'h0) &&
        (opcode <= 4'h7);

    wire iar_inst;
    assign iar_inst =
        (opcode >= 4'h8) &&
        (opcode <= 4'hD);


    // STATE REGISTER
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S0;
        end
        else if (cpu_ce) begin
            state <= next_state;
        end
    end


    // NEXT STATE LOGIC
    always @(*) begin

        next_state = S0;

        case (state)

            S0: next_state = S1;

            S1: next_state = S2;

            S2: begin
                if (alu_inst)
                    next_state = S3;
                else if (iar_inst)
                    next_state = S5;
                else if (opcode == 4'hE)
                    next_state = S14;
                else if (opcode == 4'hF)
                    next_state = S15;
            end

            S3: next_state = S4;
            S4: next_state = S5;
            S5: next_state = S6;

            S6: begin
                if (alu_inst) begin
                    next_state = S7;
                end
                else begin
                    case (opcode)

                        4'h8: next_state = S12;  // JMP
                        4'h9: next_state = S7;   // LDI
                        4'hA: next_state = S8;   // LDA
                        4'hB: next_state = S10;  // STA
                        4'hC: next_state = S13;  // JC
                        4'hD: next_state = S13;  // JZ

                        default: next_state = S0;

                    endcase
                end
            end

            S7:  next_state = S0;
            S8:  next_state = S9;
            S9:  next_state = S0;
            S10: next_state = S11;
            S11: next_state = S0;
            S12: next_state = S0;
            S13: next_state = S0;
            S14: next_state = S0;

            S15: next_state = S15;

            default: next_state = S0;

        endcase
    end


    // CONTROL SIGNAL GENERATOR
    always @(*) begin
        pc_inc      = 1'b0;
        pc_load     = 1'b0;

        mar_we      = 1'b0;
        mar_sel     = 1'b0;
        mdr_we      = 1'b0;
        ir_we       = 1'b0;
        iar_we      = 1'b0;

        operand1_we = 1'b0;
        operand2_we = 1'b0;

        gpr_we      = 1'b0;
        flag_we     = 1'b0;
        ram_we      = 1'b0;
        out_we      = 1'b0;

        wb_sel      = 2'b00;

        if (cpu_ce) begin

            case (state)

                S0: begin
                    mar_we = 1'b1;
                end

                S1: begin
                    mdr_we = 1'b1;
                    ir_we  = 1'b1;
                    pc_inc = 1'b1;
                end

                S3: begin
                    mar_we = 1'b1;
                end

                S4: begin
                    operand1_we = 1'b1;
                    pc_inc      = 1'b1;
                end

                S5: begin
                    mar_we = 1'b1;
                end

                S6: begin
                    pc_inc = 1'b1;

                    if (alu_inst)
                        operand2_we = 1'b1;
                    else if (iar_inst)
                        iar_we = 1'b1;
                end

                S7: begin
                    gpr_we = 1'b1;

                    if (alu_inst) begin
                        flag_we = 1'b1;
                        wb_sel  = 2'b00;
                    end
                    else if (opcode == 4'h9) begin
                        wb_sel = 2'b01;
                    end
                end

                S8: begin
                    mar_we  = 1'b1;
                    mar_sel = 1'b1;
                end

                S9: begin
                    mdr_we = 1'b1;
                    gpr_we = 1'b1;
                    wb_sel = 2'b10;
                end

                S10: begin
                    mar_we  = 1'b1;
                    mar_sel = 1'b1;
                end

                S11: begin
                    ram_we = 1'b1;
                end

                S12: begin
                    pc_load = 1'b1;
                end

                S13: begin
                    if (
                        ((opcode == 4'hC) && carry) ||
                        ((opcode == 4'hD) && zero)
                    ) begin
                        pc_load = 1'b1;
                    end
                end

                S14: begin
                    out_we = 1'b1;
                end

                S15: begin
                    
                end

                default: begin

                end

            endcase
        end
    end

endmodule