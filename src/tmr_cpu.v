module tmr_cpu (
    input wire clk,
    input wire reset,
    input wire cpu_ce,
    input wire run_mode,

    // Programming interface
    input wire program_we,
    input wire [7:0] program_addr,
    input wire [7:0] program_data,

    // =====================================================
    // FAULT INJECTION
    // =====================================================

    input wire fault_inject,

    // Which CPU receives the fault?
    //
    // 00 = CPU A
    // 01 = CPU B
    // 10 = CPU C
    // 11 = none
    input wire [1:0] fault_cpu,

    input wire [3:0] fault_target,
    input wire [7:0] fault_index,

    // Keep this [2:0] if your current cpu_fault still uses
    // the original 8-bit fault system.
    input wire [2:0] fault_bit,

    // =====================================================
    // VOTED OUTPUTS
    // =====================================================

    output wire [7:0] cpu_out,

    output wire zero_flag,
    output wire carry_flag,
    output wire underflow_flag,

    output wire [3:0] state_out,
    output wire [7:0] pc_debug,
    output wire [7:0] ram_debug,

    output wire halted,

    // At least one CPU disagrees with the others
    output wire mismatch
);


    // =====================================================
    // FAULT ROUTING
    //
    // IMPORTANT:
    // A deliberate fault goes to ONLY ONE CPU.
    // =====================================================

    wire fault_a;
    wire fault_b;
    wire fault_c;

    assign fault_a =
        fault_inject &&
        (fault_cpu == 2'd0);

    assign fault_b =
        fault_inject &&
        (fault_cpu == 2'd1);

    assign fault_c =
        fault_inject &&
        (fault_cpu == 2'd2);


    // =====================================================
    // CPU A OUTPUTS
    // =====================================================

    wire [7:0] out_a;

    wire z_a;
    wire c_a;
    wire u_a;

    wire [3:0] state_a;
    wire [7:0] pc_a;
    wire [7:0] ram_a;

    wire halted_a;


    // =====================================================
    // CPU B OUTPUTS
    // =====================================================

    wire [7:0] out_b;

    wire z_b;
    wire c_b;
    wire u_b;

    wire [3:0] state_b;
    wire [7:0] pc_b;
    wire [7:0] ram_b;

    wire halted_b;


    // =====================================================
    // CPU C OUTPUTS
    // =====================================================

    wire [7:0] out_c;

    wire z_c;
    wire c_c;
    wire u_c;

    wire [3:0] state_c;
    wire [7:0] pc_c;
    wire [7:0] ram_c;

    wire halted_c;


    // =====================================================
    // CPU A
    // =====================================================

    cpu_fault cpu_a (
        .clk(clk),
        .reset(reset),

        .cpu_ce(cpu_ce),
        .run_mode(run_mode),

        .program_we(program_we),
        .program_addr(program_addr),
        .program_data(program_data),

        .fault_inject(fault_a),
        .fault_target(fault_target),
        .fault_index(fault_index),
        .fault_bit(fault_bit),

        .cpu_out(out_a),

        .zero_flag(z_a),
        .carry_flag(c_a),
        .underflow_flag(u_a),

        .state_out(state_a),
        .pc_debug(pc_a),
        .ram_debug(ram_a),

        .halted(halted_a)
    );


    // =====================================================
    // CPU B
    // =====================================================

    cpu_fault cpu_b (
        .clk(clk),
        .reset(reset),

        .cpu_ce(cpu_ce),
        .run_mode(run_mode),

        .program_we(program_we),
        .program_addr(program_addr),
        .program_data(program_data),

        .fault_inject(fault_b),
        .fault_target(fault_target),
        .fault_index(fault_index),
        .fault_bit(fault_bit),

        .cpu_out(out_b),

        .zero_flag(z_b),
        .carry_flag(c_b),
        .underflow_flag(u_b),

        .state_out(state_b),
        .pc_debug(pc_b),
        .ram_debug(ram_b),

        .halted(halted_b)
    );


    // =====================================================
    // CPU C
    // =====================================================

    cpu_fault cpu_c (
        .clk(clk),
        .reset(reset),

        .cpu_ce(cpu_ce),
        .run_mode(run_mode),

        .program_we(program_we),
        .program_addr(program_addr),
        .program_data(program_data),

        .fault_inject(fault_c),
        .fault_target(fault_target),
        .fault_index(fault_index),
        .fault_bit(fault_bit),

        .cpu_out(out_c),

        .zero_flag(z_c),
        .carry_flag(c_c),
        .underflow_flag(u_c),

        .state_out(state_c),
        .pc_debug(pc_c),
        .ram_debug(ram_c),

        .halted(halted_c)
    );


    // =====================================================
    // MAJORITY VOTERS
    //
    // Formula:
    //
    // (A & B) | (A & C) | (B & C)
    //
    // Whichever value at least TWO CPUs agree on wins.
    // =====================================================


    // Main CPU output
    assign cpu_out =
        (out_a & out_b) |
        (out_a & out_c) |
        (out_b & out_c);


    // Flags
    assign zero_flag =
        (z_a & z_b) |
        (z_a & z_c) |
        (z_b & z_c);

    assign carry_flag =
        (c_a & c_b) |
        (c_a & c_c) |
        (c_b & c_c);

    assign underflow_flag =
        (u_a & u_b) |
        (u_a & u_c) |
        (u_b & u_c);


    // State
    assign state_out =
        (state_a & state_b) |
        (state_a & state_c) |
        (state_b & state_c);


    // Program Counter
    assign pc_debug =
        (pc_a & pc_b) |
        (pc_a & pc_c) |
        (pc_b & pc_c);


    // RAM debug output
    assign ram_debug =
        (ram_a & ram_b) |
        (ram_a & ram_c) |
        (ram_b & ram_c);


    // Halt
    assign halted =
        (halted_a & halted_b) |
        (halted_a & halted_c) |
        (halted_b & halted_c);


    // =====================================================
    // DISAGREEMENT DETECTOR
    // =====================================================

    assign mismatch =

        (out_a != out_b) ||
        (out_a != out_c) ||

        (state_a != state_b) ||
        (state_a != state_c) ||

        (pc_a != pc_b) ||
        (pc_a != pc_c) ||

        (halted_a != halted_b) ||
        (halted_a != halted_c);

endmodule