module cpu_fault #(
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

    // Fault injection
    input wire                  fault_inject,
    input wire [3:0]            fault_target,
    input wire [7:0]            fault_index,
    input wire [2:0]            fault_bit,

    output wire [WIDTH-1:0]     cpu_out,

    output wire                 zero_flag,
    output wire                 carry_flag,
    output wire                 underflow_flag,

    output wire [3:0]           state_out,
    output wire [WIDTH-1:0]     pc_debug,
    output wire [WIDTH-1:0]     ram_debug,
    output wire                 halted
);

    // =========================================================
    // FAULT TARGET CODES
    // =========================================================

    localparam TARGET_GPR   = 4'h0;
    localparam TARGET_PC    = 4'h1;
    localparam TARGET_IR    = 4'h2;
    localparam TARGET_IAR   = 4'h3;
    localparam TARGET_MAR   = 4'h4;
    localparam TARGET_MDR   = 4'h5;
    localparam TARGET_OP1   = 4'h6;
    localparam TARGET_OP2   = 4'h7;
    localparam TARGET_FLAGS = 4'h8;
    localparam TARGET_STATE = 4'h9;
    localparam TARGET_RAM   = 4'hA;
    localparam TARGET_OUT   = 4'hB;


    // =========================================================
    // FAULT ROUTER
    //
    // Only ONE target receives the injection pulse.
    // =========================================================

    wire fault_gpr;
    wire fault_pc;
    wire fault_ir;
    wire fault_iar;
    wire fault_mar;
    wire fault_mdr;
    wire fault_op1;
    wire fault_op2;
    wire fault_flags;
    wire fault_state;
    wire fault_ram;
    wire fault_out;

    assign fault_gpr =
        fault_inject && (fault_target == TARGET_GPR);

    assign fault_pc =
        fault_inject && (fault_target == TARGET_PC);

    assign fault_ir =
        fault_inject && (fault_target == TARGET_IR);

    assign fault_iar =
        fault_inject && (fault_target == TARGET_IAR);

    assign fault_mar =
        fault_inject && (fault_target == TARGET_MAR);

    assign fault_mdr =
        fault_inject && (fault_target == TARGET_MDR);

    assign fault_op1 =
        fault_inject && (fault_target == TARGET_OP1);

    assign fault_op2 =
        fault_inject && (fault_target == TARGET_OP2);

    assign fault_flags =
        fault_inject && (fault_target == TARGET_FLAGS);

    assign fault_state =
        fault_inject && (fault_target == TARGET_STATE);

    assign fault_ram =
        fault_inject && (fault_target == TARGET_RAM);

    assign fault_out =
        fault_inject && (fault_target == TARGET_OUT);


    // =========================================================
    // CONTROL SIGNALS
    // =========================================================

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

    assign cpu_exec_ce =
        cpu_ce & run_mode;


    // =========================================================
    // STORED VALUES
    // =========================================================

    wire [WIDTH-1:0] pc_value;
    wire [WIDTH-1:0] ir_value;
    wire [WIDTH-1:0] iar_value;
    wire [WIDTH-1:0] mar_value;
    wire [WIDTH-1:0] mdr_value;
    wire [WIDTH-1:0] operand1_value;
    wire [WIDTH-1:0] operand2_value;
    wire [WIDTH-1:0] out_value;

    wire [2:0] flag_value;


    // =========================================================
    // RAM SIGNALS
    // =========================================================

    wire [ADDR_WIDTH-1:0] ram_addr;
    wire [WIDTH-1:0] ram_din;
    wire [WIDTH-1:0] ram_dout;

    wire ram_we_final;


    // =========================================================
    // REGISTER BANK
    // =========================================================

    wire [WIDTH-1:0] src1_data;
    wire [WIDTH-1:0] src2_data;
    wire [WIDTH-1:0] direct_data;

    wire [2:0] dest_addr;


    // =========================================================
    // ALU
    // =========================================================

    wire [WIDTH-1:0] alu_out;

    wire alu_zero;
    wire alu_carry;
    wire alu_underflow;


    // =========================================================
    // WRITEBACK
    // =========================================================

    wire [WIDTH-1:0] wb_data;


    // =========================================================
    // FAULTABLE CONTROL UNIT
    // =========================================================

    faultable_control_unit cu (
        .clk(clk),
        .reset(reset),
        .cpu_ce(cpu_exec_ce),

        .ir(ir_value),
        .zero(flag_value[2]),
        .carry(flag_value[1]),

        .fault_inject(fault_state),
        .fault_bit(fault_bit),

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


    // =========================================================
    // FAULTABLE PC
    // =========================================================

    faultable_pc #(
        .WIDTH(WIDTH)
    ) pc_inst (
        .clk(clk),
        .pc_inc(pc_inc),
        .pc_load(pc_load),
        .jmp_addr(iar_value),
        .reset(reset),

        .fault_inject(fault_pc),
        .fault_bit(fault_bit),

        .pc_out(pc_value)
    );


    // =========================================================
    // MAR INPUT
    // =========================================================

    wire [WIDTH-1:0] mar_input;

    assign mar_input =
        mar_sel ? iar_value : pc_value;


    // =========================================================
    // IR
    // =========================================================

    faultable_register #(
        .WIDTH(WIDTH)
    ) ir_reg (
        .clk(clk),
        .we(ir_we),
        .reset(reset),

        .fault_inject(fault_ir),
        .fault_bit(fault_bit),

        .din(ram_dout),
        .dout(ir_value)
    );


    // =========================================================
    // IAR
    // =========================================================

    faultable_register #(
        .WIDTH(WIDTH)
    ) iar_reg (
        .clk(clk),
        .we(iar_we),
        .reset(reset),

        .fault_inject(fault_iar),
        .fault_bit(fault_bit),

        .din(ram_dout),
        .dout(iar_value)
    );


    // =========================================================
    // MAR
    // =========================================================

    faultable_register #(
        .WIDTH(WIDTH)
    ) mar_reg (
        .clk(clk),
        .we(mar_we),
        .reset(reset),

        .fault_inject(fault_mar),
        .fault_bit(fault_bit),

        .din(mar_input),
        .dout(mar_value)
    );


    // =========================================================
    // MDR
    // =========================================================

    faultable_register #(
        .WIDTH(WIDTH)
    ) mdr_reg (
        .clk(clk),
        .we(mdr_we),
        .reset(reset),

        .fault_inject(fault_mdr),
        .fault_bit(fault_bit),

        .din(ram_dout),
        .dout(mdr_value)
    );


    // =========================================================
    // OPERAND 1
    // =========================================================

    faultable_register #(
        .WIDTH(WIDTH)
    ) operand1_reg (
        .clk(clk),
        .we(operand1_we),
        .reset(reset),

        .fault_inject(fault_op1),
        .fault_bit(fault_bit),

        .din(ram_dout),
        .dout(operand1_value)
    );


    // =========================================================
    // OPERAND 2
    // =========================================================

    faultable_register #(
        .WIDTH(WIDTH)
    ) operand2_reg (
        .clk(clk),
        .we(operand2_we),
        .reset(reset),

        .fault_inject(fault_op2),
        .fault_bit(fault_bit),

        .din(ram_dout),
        .dout(operand2_value)
    );


    // =========================================================
    // FAULTABLE REGISTER BANK
    // =========================================================

    faultable_register_bank #(
        .WIDTH(WIDTH)
    ) gpr_bank (
        .clk(clk),
        .reset(reset),

        .we(gpr_we),
        .din(wb_data),
        .dest_addr(dest_addr),

        .src1_addr(operand1_value[4:2]),
        .src2_addr(operand2_value[7:5]),
        .direct_addr(ir_value[2:0]),

        .fault_inject(fault_gpr),
        .fault_index(fault_index[2:0]),
        .fault_bit(fault_bit),

        .src1_out(src1_data),
        .src2_out(src2_data),
        .direct_out(direct_data)
    );


    // =========================================================
    // ALU
    // =========================================================

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


    // =========================================================
    // FLAGS
    // =========================================================

    wire [2:0] flag_input;

    assign flag_input = {
        alu_zero,
        alu_carry,
        alu_underflow
    };


    faultable_register #(
        .WIDTH(3)
    ) flag_reg (
        .clk(clk),
        .we(flag_we),
        .reset(reset),

        .fault_inject(fault_flags),
        .fault_bit(fault_bit),

        .din(flag_input),
        .dout(flag_value)
    );


    // =========================================================
    // DESTINATION REGISTER
    // =========================================================

    assign dest_addr =
        (wb_sel == 2'b00)
        ? operand1_value[7:5]
        : ir_value[2:0];


    // =========================================================
    // WRITEBACK MUX
    // =========================================================

    assign wb_data =
        (wb_sel == 2'b00) ? alu_out   :
        (wb_sel == 2'b01) ? iar_value :
        (wb_sel == 2'b10) ? ram_dout  :
                            {WIDTH{1'b0}};


    // =========================================================
    // FAULTABLE OUT REGISTER
    // =========================================================

    faultable_register #(
        .WIDTH(WIDTH)
    ) out_reg (
        .clk(clk),
        .we(out_we),
        .reset(reset),

        .fault_inject(fault_out),
        .fault_bit(fault_bit),

        .din(direct_data),
        .dout(out_value)
    );


    // =========================================================
    // RUN / PROGRAM RAM INTERFACE
    // =========================================================

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


    // =========================================================
    // FAULTABLE RAM
    // =========================================================

    faultable_ram #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) ram_inst (
        .clk(clk),

        .we(ram_we_final),
        .mem_addr(ram_addr),

        .din(ram_din),
        .dout(ram_dout),

        .fault_inject(fault_ram),
        .fault_index(fault_index[ADDR_WIDTH-1:0]),
        .fault_bit(fault_bit)
    );


    // =========================================================
    // OUTPUTS
    // =========================================================

    assign cpu_out = out_value;

    assign zero_flag      = flag_value[2];
    assign carry_flag     = flag_value[1];
    assign underflow_flag = flag_value[0];

    assign pc_debug  = pc_value;
    assign ram_debug = ram_dout;

    assign halted =
        (state_out == 4'd15);

endmodule