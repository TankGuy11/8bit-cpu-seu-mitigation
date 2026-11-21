`timescale 1ns/1ps

// ============================================================
// LIVE-SWITCHABLE FINAL TOP
//
// mitigation_select:
//   2'b00 = Baseline faultable CPU
//   2'b01 = ECC-only CPU
//   2'b10 = ECC + scrubbing CPU
//   2'b11 = Full CPU TMR
//
// All four architectures are instantiated and run/programmed
// in parallel. The physical switch only selects which result
// is presented at the outputs.
//
// Recommended use:
//   - Program/reset/run all architectures together.
//   - Change mitigation_select while halted or reset.
// ============================================================

module final_top_switchable #(
    parameter WIDTH      = 8,
    parameter ADDR_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  cpu_ce,
    input  wire                  run_mode,

    input  wire [1:0]            mitigation_select,

    // Shared RAM programming interface
    input  wire                  program_we,
    input  wire [ADDR_WIDTH-1:0] program_addr,
    input  wire [WIDTH-1:0]      program_data,

    // Shared fault controls
    input  wire                  fault_inject,
    input  wire [1:0]            fault_cpu,     // TMR replica select
    input  wire [3:0]            fault_target,
    input  wire [7:0]            fault_index,
    input  wire [3:0]            fault_bit,

    // Selected architecture outputs
    output reg  [WIDTH-1:0]      cpu_out,
    output reg                   zero_flag,
    output reg                   carry_flag,
    output reg                   underflow_flag,
    output reg  [3:0]            state_out,
    output reg  [WIDTH-1:0]      pc_debug,
    output reg  [WIDTH-1:0]      ram_debug,
    output reg                   halted,

    // Only meaningful when mitigation_select == 2'b11
    output reg                   tmr_mismatch
);


    // ========================================================
    // BASELINE SIGNALS
    // ========================================================

    wire [WIDTH-1:0] base_out;
    wire             base_zero;
    wire             base_carry;
    wire             base_underflow;
    wire [3:0]       base_state;
    wire [WIDTH-1:0] base_pc;
    wire [WIDTH-1:0] base_ram;
    wire             base_halted;


    // ========================================================
    // ECC-ONLY SIGNALS
    // ========================================================

    wire [WIDTH-1:0] ecc_only_out;
    wire             ecc_only_zero;
    wire             ecc_only_carry;
    wire             ecc_only_underflow;
    wire [3:0]       ecc_only_state;
    wire [WIDTH-1:0] ecc_only_pc;
    wire [WIDTH-1:0] ecc_only_ram;
    wire             ecc_only_halted;


    // ========================================================
    // ECC + SCRUBBING SIGNALS
    // ========================================================

    wire [WIDTH-1:0] ecc_scrub_out;
    wire             ecc_scrub_zero;
    wire             ecc_scrub_carry;
    wire             ecc_scrub_underflow;
    wire [3:0]       ecc_scrub_state;
    wire [WIDTH-1:0] ecc_scrub_pc;
    wire [WIDTH-1:0] ecc_scrub_ram;
    wire             ecc_scrub_halted;


    // ========================================================
    // TMR SIGNALS
    // ========================================================

    wire [WIDTH-1:0] tmr_out;
    wire             tmr_zero;
    wire             tmr_carry;
    wire             tmr_underflow;
    wire [3:0]       tmr_state;
    wire [WIDTH-1:0] tmr_pc;
    wire [WIDTH-1:0] tmr_ram;
    wire             tmr_halted;
    wire             tmr_mismatch_internal;

    // ========================================================
    // FAULT-INJECTION ROUTER
    //
    // Only the architecture selected by mitigation_select receives
    // the deliberate fault pulse. All four architectures still run
    // and are programmed in parallel.
    // ========================================================

    wire base_fault_pulse;
    wire ecc_only_fault_pulse;
    wire ecc_scrub_fault_pulse;
    wire tmr_fault_pulse;

    assign base_fault_pulse =
        fault_inject && (mitigation_select == 2'b00);

    assign ecc_only_fault_pulse =
        fault_inject && (mitigation_select == 2'b01);

    assign ecc_scrub_fault_pulse =
        fault_inject && (mitigation_select == 2'b10);

    assign tmr_fault_pulse =
        fault_inject && (mitigation_select == 2'b11);



    // ========================================================
    // 0: BASELINE / UNPROTECTED FAULTABLE CPU
    // ========================================================

    cpu_fault baseline_cpu (
        .clk(clk),
        .reset(reset),

        .cpu_ce(cpu_ce),
        .run_mode(run_mode),

        .program_we(program_we),
        .program_addr(program_addr),
        .program_data(program_data),

        .fault_inject(base_fault_pulse),
        .fault_target(fault_target),
        .fault_index(fault_index),
        .fault_bit(fault_bit[2:0]),

        .cpu_out(base_out),

        .zero_flag(base_zero),
        .carry_flag(base_carry),
        .underflow_flag(base_underflow),

        .state_out(base_state),
        .pc_debug(base_pc),
        .ram_debug(base_ram),

        .halted(base_halted)
    );


    // ========================================================
    // 1: ECC-ONLY CPU
    // ========================================================

    cpu_ecc_only ecc_only_cpu (
        .clk(clk),
        .reset(reset),

        .cpu_ce(cpu_ce),
        .run_mode(run_mode),

        .program_we(program_we),
        .program_addr(program_addr),
        .program_data(program_data),

        .fault_inject(ecc_only_fault_pulse),
        .fault_target(fault_target),
        .fault_index(fault_index),
        .fault_bit(fault_bit),

        .cpu_out(ecc_only_out),

        .zero_flag(ecc_only_zero),
        .carry_flag(ecc_only_carry),
        .underflow_flag(ecc_only_underflow),

        .state_out(ecc_only_state),
        .pc_debug(ecc_only_pc),
        .ram_debug(ecc_only_ram),

        .halted(ecc_only_halted)
    );


    // ========================================================
    // 2: ECC + SCRUBBING CPU
    //
    // Your existing cpu_ecc.v is the scrub-enabled version.
    // ========================================================

    cpu_ecc ecc_scrub_cpu (
        .clk(clk),
        .reset(reset),

        .cpu_ce(cpu_ce),
        .run_mode(run_mode),

        .program_we(program_we),
        .program_addr(program_addr),
        .program_data(program_data),

        .fault_inject(ecc_scrub_fault_pulse),
        .fault_target(fault_target),
        .fault_index(fault_index),
        .fault_bit(fault_bit),

        .cpu_out(ecc_scrub_out),

        .zero_flag(ecc_scrub_zero),
        .carry_flag(ecc_scrub_carry),
        .underflow_flag(ecc_scrub_underflow),

        .state_out(ecc_scrub_state),
        .pc_debug(ecc_scrub_pc),
        .ram_debug(ecc_scrub_ram),

        .halted(ecc_scrub_halted)
    );


    // ========================================================
    // 3: FULL CPU TMR
    // ========================================================

    tmr_cpu tmr_cpu_inst (
        .clk(clk),
        .reset(reset),

        .cpu_ce(cpu_ce),
        .run_mode(run_mode),

        .program_we(program_we),
        .program_addr(program_addr),
        .program_data(program_data),

        .fault_inject(tmr_fault_pulse),
        .fault_cpu(fault_cpu),
        .fault_target(fault_target),
        .fault_index(fault_index),
        .fault_bit(fault_bit[2:0]),

        .cpu_out(tmr_out),

        .zero_flag(tmr_zero),
        .carry_flag(tmr_carry),
        .underflow_flag(tmr_underflow),

        .state_out(tmr_state),
        .pc_debug(tmr_pc),
        .ram_debug(tmr_ram),

        .halted(tmr_halted),
        .mismatch(tmr_mismatch_internal)
    );


    // ========================================================
    // LIVE OUTPUT MULTIPLEXER
    // ========================================================

    always @(*) begin

        // Safe defaults
        cpu_out        = {WIDTH{1'b0}};
        zero_flag      = 1'b0;
        carry_flag     = 1'b0;
        underflow_flag = 1'b0;
        state_out      = 4'b0000;
        pc_debug       = {WIDTH{1'b0}};
        ram_debug      = {WIDTH{1'b0}};
        halted         = 1'b0;
        tmr_mismatch   = 1'b0;

        case (mitigation_select)

            // ------------------------------------------------
            // 00: BASELINE
            // ------------------------------------------------
            2'b00: begin
                cpu_out        = base_out;
                zero_flag      = base_zero;
                carry_flag     = base_carry;
                underflow_flag = base_underflow;
                state_out      = base_state;
                pc_debug       = base_pc;
                ram_debug      = base_ram;
                halted         = base_halted;
                tmr_mismatch   = 1'b0;
            end


            // ------------------------------------------------
            // 01: ECC ONLY
            // ------------------------------------------------
            2'b01: begin
                cpu_out        = ecc_only_out;
                zero_flag      = ecc_only_zero;
                carry_flag     = ecc_only_carry;
                underflow_flag = ecc_only_underflow;
                state_out      = ecc_only_state;
                pc_debug       = ecc_only_pc;
                ram_debug      = ecc_only_ram;
                halted         = ecc_only_halted;
                tmr_mismatch   = 1'b0;
            end


            // ------------------------------------------------
            // 10: ECC + SCRUBBING
            // ------------------------------------------------
            2'b10: begin
                cpu_out        = ecc_scrub_out;
                zero_flag      = ecc_scrub_zero;
                carry_flag     = ecc_scrub_carry;
                underflow_flag = ecc_scrub_underflow;
                state_out      = ecc_scrub_state;
                pc_debug       = ecc_scrub_pc;
                ram_debug      = ecc_scrub_ram;
                halted         = ecc_scrub_halted;
                tmr_mismatch   = 1'b0;
            end


            // ------------------------------------------------
            // 11: TMR
            // ------------------------------------------------
            2'b11: begin
                cpu_out        = tmr_out;
                zero_flag      = tmr_zero;
                carry_flag     = tmr_carry;
                underflow_flag = tmr_underflow;
                state_out      = tmr_state;
                pc_debug       = tmr_pc;
                ram_debug      = tmr_ram;
                halted         = tmr_halted;
                tmr_mismatch   = tmr_mismatch_internal;
            end

            default: begin
                cpu_out        = {WIDTH{1'b0}};
                zero_flag      = 1'b0;
                carry_flag     = 1'b0;
                underflow_flag = 1'b0;
                state_out      = 4'b0000;
                pc_debug       = {WIDTH{1'b0}};
                ram_debug      = {WIDTH{1'b0}};
                halted         = 1'b0;
                tmr_mismatch   = 1'b0;
            end

        endcase

    end

endmodule
