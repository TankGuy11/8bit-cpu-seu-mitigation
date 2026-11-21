`timescale 1ns/1ps

module mitigation_campaign_tb;

    reg clk;
    always #5 clk = ~clk;

    integer i, j, k, m, n;
    integer errors;
    integer cycles;

    // =========================================================
    // PART A: STANDALONE MEMORY COMPARISON
    // =========================================================

    reg         mem_reset;
    reg         mem_we;
    reg  [7:0]  mem_addr;
    reg  [7:0]  mem_din;
    reg         mem_fault_inject;
    reg  [7:0]  mem_fault_index;
    reg  [3:0]  mem_fault_bit;
    reg         scrub_enable;

    wire [7:0]  ecc_only_dout;
    wire        ecc_only_single;
    wire        ecc_only_double;
    wire [12:0] ecc_only_corrected;

    wire [7:0]  scrub_dout;
    wire        scrub_cpu_single;
    wire        scrub_cpu_double;
    wire        scrub_single;
    wire        scrub_double;
    wire        scrub_repair;
    wire        scrub_uncorrectable;
    wire [7:0]  scrub_addr;

    ecc_ram #(.ADDR_WIDTH(8)) ecc_only_ram (
        .clk(clk),
        .reset(mem_reset),
        .we(mem_we),
        .mem_addr(mem_addr),
        .din(mem_din),
        .dout(ecc_only_dout),
        .fault_inject(mem_fault_inject),
        .fault_index(mem_fault_index),
        .fault_bit(mem_fault_bit),
        .single_error(ecc_only_single),
        .double_error(ecc_only_double),
        .corrected_codeword(ecc_only_corrected)
    );

    scrubbed_ecc_ram #(.ADDR_WIDTH(8)) scrub_ram (
        .clk(clk),
        .reset(mem_reset),
        .we(mem_we),
        .mem_addr(mem_addr),
        .din(mem_din),
        .dout(scrub_dout),
        .scrub_enable(scrub_enable),
        .fault_inject(mem_fault_inject),
        .fault_index(mem_fault_index),
        .fault_bit(mem_fault_bit),
        .cpu_single_error(scrub_cpu_single),
        .cpu_double_error(scrub_cpu_double),
        .scrub_single_error(scrub_single),
        .scrub_double_error(scrub_double),
        .scrub_repair(scrub_repair),
        .uncorrectable_seen(scrub_uncorrectable),
        .scrub_addr_debug(scrub_addr)
    );

    task mem_write;
        input [7:0] address;
        input [7:0] data;
        begin
            scrub_enable = 1'b0;
            @(negedge clk);
            mem_addr = address;
            mem_din = data;
            mem_we = 1'b1;
            @(posedge clk);
            #1;
            mem_we = 1'b0;
        end
    endtask

    task mem_flip;
        input [7:0] address;
        input [3:0] bit_number;
        begin
            scrub_enable = 1'b0;
            @(negedge clk);
            mem_fault_index = address;
            mem_fault_bit = bit_number;
            mem_fault_inject = 1'b1;
            @(posedge clk);
            #1;
            mem_fault_inject = 1'b0;
        end
    endtask

    // Reset only the scrubber control state; RAM contents are preserved.
    task reset_scrubber;
        begin
            scrub_enable = 1'b0;
            mem_reset = 1'b1;
            #2;
            mem_reset = 1'b0;
            #2;
        end
    endtask

    // Target address is 42. Starting from scrub address 0,
    // 60 clocks is enough for one visit.
    task scrub_one_pass;
        output integer saw_repair;
        integer scrub_step;
        begin
            saw_repair = 0;
            reset_scrubber;
            scrub_enable = 1'b1;

            for (scrub_step = 0; scrub_step < 60; scrub_step = scrub_step + 1) begin
                @(negedge clk);
                if (scrub_repair === 1'b1)
                    saw_repair = 1;
                @(posedge clk);
                #1;
            end

            scrub_enable = 1'b0;
        end
    endtask


    // =========================================================
    // PART B: FOUR CPU ARCHITECTURES
    // =========================================================

    reg cpu_reset;
    reg cpu_ce;
    reg run_mode;

    reg       program_we;
    reg [7:0] program_addr;
    reg [7:0] program_data;

    // Baseline
    reg       base_fault_inject;
    reg [3:0] base_fault_target;
    reg [7:0] base_fault_index;
    reg [2:0] base_fault_bit;

    // ECC only
    reg       ecconly_fault_inject;
    reg [3:0] ecconly_fault_target;
    reg [7:0] ecconly_fault_index;
    reg [3:0] ecconly_fault_bit;

    // ECC + scrubbing
    reg       scrubcpu_fault_inject;
    reg [3:0] scrubcpu_fault_target;
    reg [7:0] scrubcpu_fault_index;
    reg [3:0] scrubcpu_fault_bit;

    // TMR
    reg       tmr_fault_inject;
    reg [1:0] tmr_fault_cpu;
    reg [3:0] tmr_fault_target;
    reg [7:0] tmr_fault_index;
    reg [2:0] tmr_fault_bit;

    wire [7:0] base_out;
    wire [7:0] ecconly_out;
    wire [7:0] scrubcpu_out;
    wire [7:0] tmr_out;

    wire base_halted;
    wire ecconly_halted;
    wire scrubcpu_halted;
    wire tmr_halted;
    wire tmr_mismatch;

    wire bz, bc, bu, ez, ec, eu, sz, sc, su, tz, tc, tu;
    wire [3:0] bs, es, ss, ts;
    wire [7:0] bp, ep, sp, tp;
    wire [7:0] br, er, sr, tr;

    cpu_fault baseline_cpu (
        .clk(clk), .reset(cpu_reset),
        .cpu_ce(cpu_ce), .run_mode(run_mode),
        .program_we(program_we),
        .program_addr(program_addr),
        .program_data(program_data),
        .fault_inject(base_fault_inject),
        .fault_target(base_fault_target),
        .fault_index(base_fault_index),
        .fault_bit(base_fault_bit),
        .cpu_out(base_out),
        .zero_flag(bz), .carry_flag(bc), .underflow_flag(bu),
        .state_out(bs), .pc_debug(bp), .ram_debug(br),
        .halted(base_halted)
    );

    cpu_ecc_only ecc_only_cpu (
        .clk(clk), .reset(cpu_reset),
        .cpu_ce(cpu_ce), .run_mode(run_mode),
        .program_we(program_we),
        .program_addr(program_addr),
        .program_data(program_data),
        .fault_inject(ecconly_fault_inject),
        .fault_target(ecconly_fault_target),
        .fault_index(ecconly_fault_index),
        .fault_bit(ecconly_fault_bit),
        .cpu_out(ecconly_out),
        .zero_flag(ez), .carry_flag(ec), .underflow_flag(eu),
        .state_out(es), .pc_debug(ep), .ram_debug(er),
        .halted(ecconly_halted)
    );

    // Your already-tested cpu_ecc is the ECC + scrubbing CPU.
    cpu_ecc scrub_cpu (
        .clk(clk), .reset(cpu_reset),
        .cpu_ce(cpu_ce), .run_mode(run_mode),
        .program_we(program_we),
        .program_addr(program_addr),
        .program_data(program_data),
        .fault_inject(scrubcpu_fault_inject),
        .fault_target(scrubcpu_fault_target),
        .fault_index(scrubcpu_fault_index),
        .fault_bit(scrubcpu_fault_bit),
        .cpu_out(scrubcpu_out),
        .zero_flag(sz), .carry_flag(sc), .underflow_flag(su),
        .state_out(ss), .pc_debug(sp), .ram_debug(sr),
        .halted(scrubcpu_halted)
    );

    tmr_cpu tmr_cpu_dut (
        .clk(clk), .reset(cpu_reset),
        .cpu_ce(cpu_ce), .run_mode(run_mode),
        .program_we(program_we),
        .program_addr(program_addr),
        .program_data(program_data),
        .fault_inject(tmr_fault_inject),
        .fault_cpu(tmr_fault_cpu),
        .fault_target(tmr_fault_target),
        .fault_index(tmr_fault_index),
        .fault_bit(tmr_fault_bit),
        .cpu_out(tmr_out),
        .zero_flag(tz), .carry_flag(tc), .underflow_flag(tu),
        .state_out(ts), .pc_debug(tp), .ram_debug(tr),
        .halted(tmr_halted),
        .mismatch(tmr_mismatch)
    );

    function [3:0] ecc_data_bit;
        input [2:0] logical_bit;
        begin
            case (logical_bit)
                3'd0: ecc_data_bit = 4'd2;
                3'd1: ecc_data_bit = 4'd4;
                3'd2: ecc_data_bit = 4'd5;
                3'd3: ecc_data_bit = 4'd6;
                3'd4: ecc_data_bit = 4'd8;
                3'd5: ecc_data_bit = 4'd9;
                3'd6: ecc_data_bit = 4'd10;
                3'd7: ecc_data_bit = 4'd11;
                default: ecc_data_bit = 4'd0;
            endcase
        end
    endfunction

    task program_all;
        input [7:0] address;
        input [7:0] data;
        begin
            cpu_ce = 1'b0;
            run_mode = 1'b0;
            @(negedge clk);
            program_addr = address;
            program_data = data;
            program_we = 1'b1;
            @(posedge clk);
            #1;
            program_we = 1'b0;
        end
    endtask

    task reset_cpus;
        begin
            cpu_ce = 1'b0;
            run_mode = 1'b0;
            cpu_reset = 1'b1;
            #2;
            cpu_reset = 1'b0;
            #2;
        end
    endtask

    task run_all_cpus;
        begin
            run_mode = 1'b1;
            cpu_ce = 1'b1;
            cycles = 0;

            while (
                (base_halted !== 1'b1 ||
                 ecconly_halted !== 1'b1 ||
                 scrubcpu_halted !== 1'b1 ||
                 tmr_halted !== 1'b1)
                 && cycles < 200
            ) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end

            cpu_ce = 1'b0;

            if (cycles >= 200) begin
                $display("WARNING: CPU trial timed out");
                errors = errors + 1;
            end
        end
    endtask

    task pulse_all_faults;
        begin
            @(negedge clk);
            base_fault_inject     = 1'b1;
            ecconly_fault_inject  = 1'b1;
            scrubcpu_fault_inject = 1'b1;
            tmr_fault_inject      = 1'b1;

            @(posedge clk);
            #1;

            base_fault_inject     = 1'b0;
            ecconly_fault_inject  = 1'b0;
            scrubcpu_fault_inject = 1'b0;
            tmr_fault_inject      = 1'b0;
        end
    endtask

    task set_fault_bit;
        input [2:0] logical_bit;
        begin
            base_fault_target = 4'hA;
            base_fault_index  = 8'd20;
            base_fault_bit    = logical_bit;

            ecconly_fault_target = 4'hA;
            ecconly_fault_index  = 8'd20;
            ecconly_fault_bit    = ecc_data_bit(logical_bit);

            scrubcpu_fault_target = 4'hA;
            scrubcpu_fault_index  = 8'd20;
            scrubcpu_fault_bit    = ecc_data_bit(logical_bit);

            tmr_fault_cpu    = 2'd2; // CPU C only
            tmr_fault_target = 4'hA;
            tmr_fault_index  = 8'd20;
            tmr_fault_bit    = logical_bit;
        end
    endtask


    // =========================================================
    // RESULT COUNTERS
    // =========================================================

    integer ecc_single_correct;
    integer ecc_single_flagged;
    integer ecc_double_detect;

    integer ecc_triple_correct;
    integer ecc_triple_single_flag;
    integer ecc_triple_double_flag;
    integer ecc_triple_silent_wrong;

    integer ecc_quad_correct;
    integer ecc_quad_single_flag;
    integer ecc_quad_double_flag;
    integer ecc_quad_silent_wrong;

    integer scrub_single_repairs;
    integer scrub_double_false_repairs;
    integer scrub_triple_repairs;
    integer scrub_triple_wrong_after;
    integer scrub_quad_repairs;
    integer scrub_quad_wrong_after;

    integer saw_repair;
    // Save the pre-fault encoded memory word for exact restoration checks.
    reg [12:0] expected_codeword;
    integer scrub_triple_raw_restored;
    integer scrub_quad_raw_restored;

    integer base_single_correct;
    integer ecconly_single_correct;
    integer scrubcpu_single_correct;
    integer tmr_single_correct;
    integer tmr_single_mismatch;

    integer base_double_correct;
    integer ecconly_double_correct;
    integer scrubcpu_double_correct;
    integer tmr_double_correct;
    integer tmr_double_mismatch;

    integer ecconly_double_detect_cpu;
    integer scrubcpu_double_detect_cpu;


    // =========================================================
    // MAIN
    // =========================================================

    initial begin
        $dumpfile("build/mitigation_campaign.vcd");
        $dumpvars(0, mitigation_campaign_tb);

        clk = 0;
        errors = 0;

        mem_reset = 0;
        mem_we = 0;
        mem_addr = 0;
        mem_din = 0;
        mem_fault_inject = 0;
        mem_fault_index = 0;
        mem_fault_bit = 0;
        scrub_enable = 0;

        cpu_reset = 0;
        cpu_ce = 0;
        run_mode = 0;
        program_we = 0;
        program_addr = 0;
        program_data = 0;

        base_fault_inject = 0;
        base_fault_target = 0;
        base_fault_index = 0;
        base_fault_bit = 0;

        ecconly_fault_inject = 0;
        ecconly_fault_target = 0;
        ecconly_fault_index = 0;
        ecconly_fault_bit = 0;

        scrubcpu_fault_inject = 0;
        scrubcpu_fault_target = 0;
        scrubcpu_fault_index = 0;
        scrubcpu_fault_bit = 0;

        tmr_fault_inject = 0;
        tmr_fault_cpu = 2'b11;
        tmr_fault_target = 0;
        tmr_fault_index = 0;
        tmr_fault_bit = 0;

        ecc_single_correct = 0;
        ecc_single_flagged = 0;
        ecc_double_detect = 0;

        ecc_triple_correct = 0;
        ecc_triple_single_flag = 0;
        ecc_triple_double_flag = 0;
        ecc_triple_silent_wrong = 0;

        ecc_quad_correct = 0;
        ecc_quad_single_flag = 0;
        ecc_quad_double_flag = 0;
        ecc_quad_silent_wrong = 0;

        scrub_single_repairs = 0;
        scrub_double_false_repairs = 0;
        scrub_triple_repairs = 0;
        scrub_triple_wrong_after = 0;
        scrub_quad_repairs = 0;
        scrub_quad_wrong_after = 0;
        scrub_triple_raw_restored = 0;
        scrub_quad_raw_restored = 0;

        base_single_correct = 0;
        ecconly_single_correct = 0;
        scrubcpu_single_correct = 0;
        tmr_single_correct = 0;
        tmr_single_mismatch = 0;

        base_double_correct = 0;
        ecconly_double_correct = 0;
        scrubcpu_double_correct = 0;
        tmr_double_correct = 0;
        tmr_double_mismatch = 0;

        ecconly_double_detect_cpu = 0;
        scrubcpu_double_detect_cpu = 0;


        // =====================================================
        // A1. ECC-ONLY: ALL 13 SINGLE-BIT PHYSICAL FAULTS
        // =====================================================

        $display("");
        $display("==============================================");
        $display("A1: ECC-ONLY SINGLE-BIT EXHAUSTIVE TEST");
        $display("==============================================");

        for (i = 0; i < 13; i = i + 1) begin
            mem_write(8'd42, 8'hA5);
            mem_flip(8'd42, i[3:0]);
            mem_addr = 8'd42;
            #1;

            if (ecc_only_dout === 8'hA5)
                ecc_single_correct = ecc_single_correct + 1;

            if (ecc_only_single === 1'b1)
                ecc_single_flagged = ecc_single_flagged + 1;
        end


        // =====================================================
        // A2. ECC-ONLY: ALL 78 DOUBLE-BIT COMBINATIONS
        // =====================================================

        $display("A2: ECC-ONLY DOUBLE-BIT EXHAUSTIVE TEST");

        for (i = 0; i < 13; i = i + 1) begin
            for (j = i + 1; j < 13; j = j + 1) begin
                mem_write(8'd42, 8'hA5);
                mem_flip(8'd42, i[3:0]);
                mem_flip(8'd42, j[3:0]);
                mem_addr = 8'd42;
                #1;

                if (ecc_only_double === 1'b1)
                    ecc_double_detect = ecc_double_detect + 1;
            end
        end


        // =====================================================
        // A3. ECC-ONLY: ALL 286 TRIPLE-BIT COMBINATIONS
        // Characterization only: SECDED makes no guarantee here.
        // =====================================================

        $display("A3: ECC-ONLY TRIPLE-BIT CHARACTERIZATION");

        for (i = 0; i < 13; i = i + 1) begin
            for (j = i + 1; j < 13; j = j + 1) begin
                for (k = j + 1; k < 13; k = k + 1) begin
                    mem_write(8'd42, 8'hA5);
                    mem_flip(8'd42, i[3:0]);
                    mem_flip(8'd42, j[3:0]);
                    mem_flip(8'd42, k[3:0]);
                    mem_addr = 8'd42;
                    #1;

                    if (ecc_only_dout === 8'hA5)
                        ecc_triple_correct = ecc_triple_correct + 1;

                    if (ecc_only_single === 1'b1)
                        ecc_triple_single_flag = ecc_triple_single_flag + 1;

                    if (ecc_only_double === 1'b1)
                        ecc_triple_double_flag = ecc_triple_double_flag + 1;

                    if ((ecc_only_dout !== 8'hA5) &&
                        (ecc_only_single !== 1'b1) &&
                        (ecc_only_double !== 1'b1))
                        ecc_triple_silent_wrong = ecc_triple_silent_wrong + 1;
                end
            end
        end


        // =====================================================
        // A4. ECC-ONLY: ALL 715 FOUR-BIT COMBINATIONS
        // Characterization only.
        // =====================================================

        $display("A4: ECC-ONLY FOUR-BIT CHARACTERIZATION");

        for (i = 0; i < 13; i = i + 1) begin
            for (j = i + 1; j < 13; j = j + 1) begin
                for (k = j + 1; k < 13; k = k + 1) begin
                    for (m = k + 1; m < 13; m = m + 1) begin
                        mem_write(8'd42, 8'hA5);
                        mem_flip(8'd42, i[3:0]);
                        mem_flip(8'd42, j[3:0]);
                        mem_flip(8'd42, k[3:0]);
                        mem_flip(8'd42, m[3:0]);
                        mem_addr = 8'd42;
                        #1;

                        if (ecc_only_dout === 8'hA5)
                            ecc_quad_correct = ecc_quad_correct + 1;

                        if (ecc_only_single === 1'b1)
                            ecc_quad_single_flag = ecc_quad_single_flag + 1;

                        if (ecc_only_double === 1'b1)
                            ecc_quad_double_flag = ecc_quad_double_flag + 1;

                        if ((ecc_only_dout !== 8'hA5) &&
                            (ecc_only_single !== 1'b1) &&
                            (ecc_only_double !== 1'b1))
                            ecc_quad_silent_wrong = ecc_quad_silent_wrong + 1;
                    end
                end
            end
        end


        // =====================================================
        // B1. SCRUBBING: ALL 13 SINGLE-BIT FAULTS
        // =====================================================

        $display("B1: SCRUBBER SINGLE-BIT REPAIR TEST");

        for (i = 0; i < 13; i = i + 1) begin
            mem_write(8'd42, 8'hA5);

            // Save original RAW 13-bit stored codeword before injection.
            expected_codeword = scrub_ram.ram_segment[8'd42];
            mem_flip(8'd42, i[3:0]);
            scrub_one_pass(saw_repair);

            mem_addr = 8'd42;
            #1;

            // A pass now requires a scrub request, correct decoded data,
            // AND exact restoration of all thirteen stored bits.
            if (saw_repair &&
                scrub_dout === 8'hA5 &&
                scrub_ram.ram_segment[8'd42] === expected_codeword)
                scrub_single_repairs = scrub_single_repairs + 1;
            else
                $display("B1 FAIL bit=%0d repair=%0d decoded=%02h raw=%04h expected=%04h",
                         i, saw_repair, scrub_dout,
                         scrub_ram.ram_segment[8'd42], expected_codeword);
        end


        // =====================================================
        // B2. SCRUBBING: ALL 78 DOUBLE-BIT FAULTS
        // Correct behavior is NO repair.
        // =====================================================

        $display("B2: SCRUBBER DOUBLE-BIT NO-REPAIR TEST");

        for (i = 0; i < 13; i = i + 1) begin
            for (j = i + 1; j < 13; j = j + 1) begin
                mem_write(8'd42, 8'hA5);
                mem_flip(8'd42, i[3:0]);
                mem_flip(8'd42, j[3:0]);
                scrub_one_pass(saw_repair);

                if (saw_repair)
                    scrub_double_false_repairs =
                        scrub_double_false_repairs + 1;
            end
        end


        // =====================================================
        // B3. SCRUBBING: TRIPLE-BIT CHARACTERIZATION
        // A triple fault can look like a single fault to SECDED.
        // Count any scrub writes and whether the final data is wrong.
        // =====================================================

        $display("B3: SCRUBBER TRIPLE-BIT CHARACTERIZATION");

        for (i = 0; i < 13; i = i + 1) begin
            for (j = i + 1; j < 13; j = j + 1) begin
                for (k = j + 1; k < 13; k = k + 1) begin
                    mem_write(8'd42, 8'hA5);
                    expected_codeword = scrub_ram.ram_segment[8'd42];
                    mem_flip(8'd42, i[3:0]);
                    mem_flip(8'd42, j[3:0]);
                    mem_flip(8'd42, k[3:0]);
                    scrub_one_pass(saw_repair);

                    mem_addr = 8'd42;
                    #1;

                    if (saw_repair)
                        scrub_triple_repairs =
                            scrub_triple_repairs + 1;

                    if (scrub_dout !== 8'hA5)
                        scrub_triple_wrong_after =
                            scrub_triple_wrong_after + 1;

                    if (scrub_ram.ram_segment[8'd42] === expected_codeword)
                        scrub_triple_raw_restored =
                            scrub_triple_raw_restored + 1;
                end
            end
        end


        // =====================================================
        // B4. SCRUBBING: FOUR-BIT CHARACTERIZATION
        // =====================================================

        $display("B4: SCRUBBER FOUR-BIT CHARACTERIZATION");

        for (i = 0; i < 13; i = i + 1) begin
            for (j = i + 1; j < 13; j = j + 1) begin
                for (k = j + 1; k < 13; k = k + 1) begin
                    for (n = k + 1; n < 13; n = n + 1) begin
                        mem_write(8'd42, 8'hA5);
                        expected_codeword = scrub_ram.ram_segment[8'd42];
                        mem_flip(8'd42, i[3:0]);
                        mem_flip(8'd42, j[3:0]);
                        mem_flip(8'd42, k[3:0]);
                        mem_flip(8'd42, n[3:0]);
                        scrub_one_pass(saw_repair);

                        mem_addr = 8'd42;
                        #1;

                        if (saw_repair)
                            scrub_quad_repairs =
                                scrub_quad_repairs + 1;

                        if (scrub_dout !== 8'hA5)
                            scrub_quad_wrong_after =
                                scrub_quad_wrong_after + 1;

                        if (scrub_ram.ram_segment[8'd42] === expected_codeword)
                            scrub_quad_raw_restored =
                                scrub_quad_raw_restored + 1;
                    end
                end
            end
        end


        // =====================================================
        // PROGRAM CPU WORKLOAD
        //
        // 0: LDA R2
        // 1: address 20
        // 2: OUT R2
        // 3: HLT
        // 20: data 5
        // =====================================================

        $display("");
        $display("==============================================");
        $display("C: PROGRAMMING CPU-LEVEL COMPARISON");
        $display("==============================================");

        program_all(8'd0,  8'b10100010);
        program_all(8'd1,  8'd20);
        program_all(8'd2,  8'b11100010);
        program_all(8'd3,  8'b11110000);
        program_all(8'd20, 8'd5);


        // =====================================================
        // C1. ALL 8 SINGLE LOGICAL DATA-BIT FAULTS
        // =====================================================

        $display("C1: CPU SINGLE-DATA-BIT SWEEP");

        for (i = 0; i < 8; i = i + 1) begin
            program_all(8'd20, 8'd5);
            reset_cpus;

            set_fault_bit(i[2:0]);
            pulse_all_faults;

            run_all_cpus;

            if (base_out === 8'd5)
                base_single_correct = base_single_correct + 1;

            if (ecconly_out === 8'd5)
                ecconly_single_correct = ecconly_single_correct + 1;

            if (scrubcpu_out === 8'd5)
                scrubcpu_single_correct = scrubcpu_single_correct + 1;

            if (tmr_out === 8'd5)
                tmr_single_correct = tmr_single_correct + 1;

            if (tmr_mismatch === 1'b1)
                tmr_single_mismatch = tmr_single_mismatch + 1;
        end


        // =====================================================
        // C2. ALL 28 DOUBLE LOGICAL DATA-BIT FAULTS
        // =====================================================

        $display("C2: CPU DOUBLE-DATA-BIT SWEEP");

        for (i = 0; i < 8; i = i + 1) begin
            for (j = i + 1; j < 8; j = j + 1) begin
                program_all(8'd20, 8'd5);
                reset_cpus;

                set_fault_bit(i[2:0]);
                pulse_all_faults;

                set_fault_bit(j[2:0]);
                pulse_all_faults;

                // Temporarily select RAM[20] directly so we can sample
                // the ECC detection status before CPU execution.
                run_mode = 1'b0;
                program_addr = 8'd20;
                #1;

                if (ecc_only_cpu.ram_inst.double_error === 1'b1)
                    ecconly_double_detect_cpu =
                        ecconly_double_detect_cpu + 1;

                if (scrub_cpu.ram_inst.cpu_double_error === 1'b1)
                    scrubcpu_double_detect_cpu =
                        scrubcpu_double_detect_cpu + 1;

                run_all_cpus;

                if (base_out === 8'd5)
                    base_double_correct = base_double_correct + 1;

                if (ecconly_out === 8'd5)
                    ecconly_double_correct = ecconly_double_correct + 1;

                if (scrubcpu_out === 8'd5)
                    scrubcpu_double_correct = scrubcpu_double_correct + 1;

                if (tmr_out === 8'd5)
                    tmr_double_correct = tmr_double_correct + 1;

                if (tmr_mismatch === 1'b1)
                    tmr_double_mismatch = tmr_double_mismatch + 1;
            end
        end


        // =====================================================
        // FINAL RESULTS
        // =====================================================

        $display("");
        $display("====================================================");
        $display("FINAL SEU MITIGATION CAMPAIGN RESULTS");
        $display("====================================================");

        $display("");
        $display("ECC-ONLY MEMORY");
        $display("----------------------------------------------");
        $display("1-bit correct output       : %0d / 13", ecc_single_correct);
        $display("1-bit single-error flag    : %0d / 13", ecc_single_flagged);
        $display("2-bit detected             : %0d / 78", ecc_double_detect);
        $display("3-bit correct output       : %0d / 286", ecc_triple_correct);
        $display("3-bit flagged as single    : %0d / 286", ecc_triple_single_flag);
        $display("3-bit flagged as double    : %0d / 286", ecc_triple_double_flag);
        $display("3-bit silent wrong output  : %0d / 286", ecc_triple_silent_wrong);
        $display("4-bit correct output       : %0d / 715", ecc_quad_correct);
        $display("4-bit flagged as single    : %0d / 715", ecc_quad_single_flag);
        $display("4-bit flagged as double    : %0d / 715", ecc_quad_double_flag);
        $display("4-bit silent wrong output  : %0d / 715", ecc_quad_silent_wrong);

        $display("");
        $display("ECC + SCRUBBING MEMORY");
        $display("----------------------------------------------");
        $display("1-bit repaired             : %0d / 13", scrub_single_repairs);
        $display("2-bit false repairs        : %0d / 78", scrub_double_false_repairs);
        $display("3-bit scrub writes         : %0d / 286", scrub_triple_repairs);
        $display("3-bit wrong after scrub    : %0d / 286", scrub_triple_wrong_after);
        $display("4-bit scrub writes         : %0d / 715", scrub_quad_repairs);
        $display("4-bit wrong after scrub    : %0d / 715", scrub_quad_wrong_after);
        $display("3-bit raw codeword restored: %0d / 286", scrub_triple_raw_restored);
        $display("4-bit raw codeword restored: %0d / 715", scrub_quad_raw_restored);

        $display("");
        $display("CPU-LEVEL: 8 SINGLE LOGICAL RAM DATA-BIT FAULTS");
        $display("----------------------------------------------");
        $display("Baseline correct           : %0d / 8", base_single_correct);
        $display("ECC-only correct           : %0d / 8", ecconly_single_correct);
        $display("ECC+scrub correct          : %0d / 8", scrubcpu_single_correct);
        $display("TMR correct                : %0d / 8", tmr_single_correct);
        $display("TMR mismatch detected      : %0d / 8", tmr_single_mismatch);

        $display("");
        $display("CPU-LEVEL: 28 DOUBLE LOGICAL RAM DATA-BIT FAULTS");
        $display("----------------------------------------------");
        $display("Baseline correct           : %0d / 28", base_double_correct);
        $display("ECC-only correct           : %0d / 28", ecconly_double_correct);
        $display("ECC-only double detected   : %0d / 28", ecconly_double_detect_cpu);
        $display("ECC+scrub correct          : %0d / 28", scrubcpu_double_correct);
        $display("ECC+scrub double detected  : %0d / 28", scrubcpu_double_detect_cpu);
        $display("TMR correct                : %0d / 28", tmr_double_correct);
        $display("TMR mismatch detected      : %0d / 28", tmr_double_mismatch);

        $display("");
        $display("GUARANTEED SECDED CHECKS");
        $display("----------------------------------------------");

        if (ecc_single_correct == 13 &&
            ecc_single_flagged == 13 &&
            ecc_double_detect == 78 &&
            scrub_single_repairs == 13 &&
            scrub_double_false_repairs == 0 &&
            ecconly_single_correct == 8 &&
            scrubcpu_single_correct == 8 &&
            tmr_single_correct == 8 &&
            ecconly_double_detect_cpu == 28 &&
            scrubcpu_double_detect_cpu == 28 &&
            tmr_double_correct == 28) begin

            $display("ALL GUARANTEED MITIGATION BEHAVIOURS PASSED");
        end
        else begin
            $display("ONE OR MORE GUARANTEED BEHAVIOURS FAILED");
            errors = errors + 1;
        end

        $display("");
        $display("NOTE: 3-bit and 4-bit values are CHARACTERIZATION");
        $display("results, not SECDED guarantees.");

        $finish;
    end

endmodule
