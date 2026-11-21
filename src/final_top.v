`timescale 1ns/1ps

// Final logical top layer.
// ARCH = 0 : unprotected faultable CPU
// ARCH = 1 : ECC-only CPU
// ARCH = 2 : ECC + memory scrubbing CPU
// ARCH = 3 : full-CPU TMR
//
// This is intentionally a compile-time selection so only the chosen
// architecture is synthesized into the FPGA bitstream.

module final_top #(
    parameter ARCH       = 0,
    parameter WIDTH      = 8,
    parameter ADDR_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  cpu_ce,
    input  wire                  run_mode,

    input  wire                  program_we,
    input  wire [ADDR_WIDTH-1:0] program_addr,
    input  wire [WIDTH-1:0]      program_data,

    input  wire                  fault_inject,
    input  wire [1:0]            fault_cpu,    // only used by TMR
    input  wire [3:0]            fault_target,
    input  wire [7:0]            fault_index,
    input  wire [3:0]            fault_bit,

    output wire [WIDTH-1:0]      cpu_out,
    output wire                  zero_flag,
    output wire                  carry_flag,
    output wire                  underflow_flag,
    output wire [3:0]            state_out,
    output wire [WIDTH-1:0]      pc_debug,
    output wire [WIDTH-1:0]      ram_debug,
    output wire                  halted,

    // Valid only for ARCH=3. It is tied low otherwise.
    output wire                  tmr_mismatch
);

    generate

        if (ARCH == 0) begin : GEN_BASELINE

            cpu_fault dut (
                .clk(clk),
                .reset(reset),
                .cpu_ce(cpu_ce),
                .run_mode(run_mode),

                .program_we(program_we),
                .program_addr(program_addr),
                .program_data(program_data),

                .fault_inject(fault_inject),
                .fault_target(fault_target),
                .fault_index(fault_index),
                .fault_bit(fault_bit[2:0]),

                .cpu_out(cpu_out),
                .zero_flag(zero_flag),
                .carry_flag(carry_flag),
                .underflow_flag(underflow_flag),
                .state_out(state_out),
                .pc_debug(pc_debug),
                .ram_debug(ram_debug),
                .halted(halted)
            );

            assign tmr_mismatch = 1'b0;

        end
        else if (ARCH == 1) begin : GEN_ECC_ONLY

            cpu_ecc_only dut (
                .clk(clk),
                .reset(reset),
                .cpu_ce(cpu_ce),
                .run_mode(run_mode),

                .program_we(program_we),
                .program_addr(program_addr),
                .program_data(program_data),

                .fault_inject(fault_inject),
                .fault_target(fault_target),
                .fault_index(fault_index),
                .fault_bit(fault_bit),

                .cpu_out(cpu_out),
                .zero_flag(zero_flag),
                .carry_flag(carry_flag),
                .underflow_flag(underflow_flag),
                .state_out(state_out),
                .pc_debug(pc_debug),
                .ram_debug(ram_debug),
                .halted(halted)
            );

            assign tmr_mismatch = 1'b0;

        end
        else if (ARCH == 2) begin : GEN_ECC_SCRUB

            // Your already-tested cpu_ecc.v is the ECC + scrubbing CPU.
            cpu_ecc dut (
                .clk(clk),
                .reset(reset),
                .cpu_ce(cpu_ce),
                .run_mode(run_mode),

                .program_we(program_we),
                .program_addr(program_addr),
                .program_data(program_data),

                .fault_inject(fault_inject),
                .fault_target(fault_target),
                .fault_index(fault_index),
                .fault_bit(fault_bit),

                .cpu_out(cpu_out),
                .zero_flag(zero_flag),
                .carry_flag(carry_flag),
                .underflow_flag(underflow_flag),
                .state_out(state_out),
                .pc_debug(pc_debug),
                .ram_debug(ram_debug),
                .halted(halted)
            );

            assign tmr_mismatch = 1'b0;

        end
        else begin : GEN_TMR

            tmr_cpu dut (
                .clk(clk),
                .reset(reset),
                .cpu_ce(cpu_ce),
                .run_mode(run_mode),

                .program_we(program_we),
                .program_addr(program_addr),
                .program_data(program_data),

                .fault_inject(fault_inject),
                .fault_cpu(fault_cpu),
                .fault_target(fault_target),
                .fault_index(fault_index),
                .fault_bit(fault_bit[2:0]),

                .cpu_out(cpu_out),
                .zero_flag(zero_flag),
                .carry_flag(carry_flag),
                .underflow_flag(underflow_flag),
                .state_out(state_out),
                .pc_debug(pc_debug),
                .ram_debug(ram_debug),
                .halted(halted),
                .mismatch(tmr_mismatch)
            );

        end

    endgenerate

endmodule
