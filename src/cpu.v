module cpu #(
    parameter WIDTH = 8,
    parameter DEPTH = 256,
    parameter ADDR_WIDTH = 8
)(
    input wire                  clk,
    input wire                  reset,

    input wire                  cpu_ce,
    input wire                  run_mode,

    input wire                  program_we,
    input wire [ADDR_WIDTH-1:0] program_addr,
    input wire [WIDTH-1:0]      program_data,

    output wire [WIDTH-1:0]     cpu_out,

    output wire                 zero_flag,
    output wire                 carry_flag,
    output wire                 underflow_flag,

    output wire [3:0]           state_out,
    output wire [WIDTH-1:0]     pc_debug,
    output wire [WIDTH-1:0]     ram_debug,
    output wire                 halted
);

    wire pc_inc;
    wire pc_load;

    wire mar_we;
    wire mar_sel;
    wire mdr_we;
    wire ir_we;
    wire iar_we;

    wire operand1_we;
    wire operand2_we;

    wire gpr_we;
    wire flag_we;
    wire cpu_ram_we;
    wire out_we;

    wire [1:0] wb_sel;
    wire [2:0] alu_opcodes;

    wire cpu_exec_ce;

    assign cpu_exec_ce = cpu_ce & run_mode;

    wire [WIDTH-1:0] pc_value;
    wire [WIDTH-1:0] ir_value;
    wire [WIDTH-1:0] iar_value;
    wire [WIDTH-1:0] mar_value;
    wire [WIDTH-1:0] mdr_value;
    wire [WIDTH-1:0] operand1_value;
    wire [WIDTH-1:0] operand2_value;
    wire [WIDTH-1:0] out_value;

    wire [2:0] flag_value;

    wire [ADDR_WIDTH-1:0] ram_addr;
    wire [WIDTH-1:0]      ram_din;
    wire [WIDTH-1:0]      ram_dout;
    wire                  ram_we_final;

    wire [WIDTH-1:0] src1_data;
    wire [WIDTH-1:0] src2_data;
    wire [WIDTH-1:0] direct_data;

    wire [2:0] dest_addr;

    wire [WIDTH-1:0] alu_out;
    wire             alu_zero;
    wire             alu_carry;
    wire             alu_underflow;

    wire [WIDTH-1:0] wb_data;

    control_unit cu (
        .clk(clk),
        .reset(reset),
        .cpu_ce(cpu_exec_ce),

        .ir(ir_value),
        .zero(flag_value[2]),
        .carry(flag_value[1]),

        .pc_inc(pc_inc),
        .pc_load(pc_load),

        .mar_we(mar_we),
        .mar_sel(mar_sel),
        .mdr_we(mdr_we),
        .ir_we(ir_we),
        .iar_we(iar_we),

        .operand1_we(operand1_we),
        .operand2_we(operand2_we),

        .gpr_we(gpr_we),
        .flag_we(flag_we),
        .ram_we(cpu_ram_we),
        .out_we(out_we),

        .wb_sel(wb_sel),
        .alu_opcodes(alu_opcodes),
        .state_out(state_out)
    );

    pc #(
        .WIDTH(WIDTH)
    ) pc_inst (
        .clk(clk),
        .reset(reset),
        .pc_inc(pc_inc),
        .pc_load(pc_load),
        .jmp_addr(iar_value),
        .pc_out(pc_value)
    );

    wire [WIDTH-1:0] mar_input;

    assign mar_input =
        mar_sel ? iar_value : pc_value;

    register #(
        .WIDTH(WIDTH)
    ) ir_reg (
        .clk(clk),
        .we(ir_we),
        .reset(reset),
        .din(ram_dout),
        .dout(ir_value)
    );

    register #(
        .WIDTH(WIDTH)
    ) iar_reg (
        .clk(clk),
        .we(iar_we),
        .reset(reset),
        .din(ram_dout),
        .dout(iar_value)
    );

    register #(
        .WIDTH(WIDTH)
    ) mar_reg (
        .clk(clk),
        .we(mar_we),
        .reset(reset),
        .din(mar_input),
        .dout(mar_value)
    );

    register #(
        .WIDTH(WIDTH)
    ) mdr_reg (
        .clk(clk),
        .we(mdr_we),
        .reset(reset),
        .din(ram_dout),
        .dout(mdr_value)
    );

    register #(
        .WIDTH(WIDTH)
    ) operand1_reg (
        .clk(clk),
        .we(operand1_we),
        .reset(reset),
        .din(ram_dout),
        .dout(operand1_value)
    );

    register #(
        .WIDTH(WIDTH)
    ) operand2_reg (
        .clk(clk),
        .we(operand2_we),
        .reset(reset),
        .din(ram_dout),
        .dout(operand2_value)
    );

    register_bank #(
        .WIDTH(WIDTH)
    ) gpr_bank (
        .clk(clk),
        .gpr_we(gpr_we),
        .reset(reset),

        .din(wb_data),
        .dest_addr(dest_addr),

        .src1_addr(operand1_value[4:2]),
        .src2_addr(operand2_value[7:5]),
        .direct_addr(ir_value[2:0]),

        .src1_out(src1_data),
        .src2_out(src2_data),
        .direct_out(direct_data)
    );

    alu #(
        .WIDTH(WIDTH)
    ) alu_inst (
        .alu_opcodes(alu_opcodes),

        .a(src1_data),
        .b(src2_data),

        .alu_out(alu_out),
        .zero(alu_zero),
        .carry(alu_carry),
        .underflow(alu_underflow)
    );

    wire [2:0] flag_input;

    assign flag_input = {
        alu_zero,
        alu_carry,
        alu_underflow
    };

    register #(
        .WIDTH(3)
    ) flag_reg (
        .clk(clk),
        .we(flag_we),
        .reset(reset),
        .din(flag_input),
        .dout(flag_value)
    );

    assign dest_addr =
        (wb_sel == 2'b00)
        ? operand1_value[7:5]
        : ir_value[2:0];

    assign wb_data =
        (wb_sel == 2'b00) ? alu_out   :
        (wb_sel == 2'b01) ? iar_value :
        (wb_sel == 2'b10) ? ram_dout  :
                            {WIDTH{1'b0}};

    register #(
        .WIDTH(WIDTH)
    ) out_reg (
        .clk(clk),
        .we(out_we),
        .reset(reset),
        .din(direct_data),
        .dout(out_value)
    );

    assign ram_addr =
        run_mode
        ? mar_value[ADDR_WIDTH-1:0]
        : program_addr;

    assign ram_din =
        run_mode
        ? direct_data
        : program_data;

    assign ram_we_final =
        run_mode
        ? cpu_ram_we
        : program_we;

    ram #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) ram_inst (
        .clk(clk),
        .we(ram_we_final),
        .mem_addr(ram_addr),
        .din(ram_din),
        .dout(ram_dout)
    );

    assign cpu_out = out_value;

    assign zero_flag      = flag_value[2];
    assign carry_flag     = flag_value[1];
    assign underflow_flag = flag_value[0];

    assign pc_debug  = pc_value;
    assign ram_debug = ram_dout;

    assign halted =
        (state_out == 4'd15);

endmodule