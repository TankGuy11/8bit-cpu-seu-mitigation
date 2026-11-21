module scrubbed_ecc_ram #(
    parameter ADDR_WIDTH = 8
)(
    input wire clk,
    input wire reset,

    // =====================================================
    // CPU INTERFACE
    // =====================================================

    input wire we,
    input wire [ADDR_WIDTH-1:0] mem_addr,
    input wire [7:0] din,

    output wire [7:0] dout,


    // =====================================================
    // SCRUBBING
    // =====================================================

    input wire scrub_enable,


    // =====================================================
    // FAULT INJECTION
    // =====================================================

    input wire fault_inject,
    input wire [ADDR_WIDTH-1:0] fault_index,

    // 4 bits required because ECC RAM has 13 stored bits
    input wire [3:0] fault_bit,


    // =====================================================
    // STATUS
    // =====================================================

    output wire cpu_single_error,
    output wire cpu_double_error,

    output wire scrub_single_error,
    output wire scrub_double_error,

    output wire scrub_repair,

    output reg uncorrectable_seen,

    output wire [ADDR_WIDTH-1:0] scrub_addr_debug
);


    // =====================================================
    // ACTUAL MEMORY
    //
    // Each logical 8-bit word becomes a 13-bit SECDED word.
    // =====================================================

    reg [12:0] ram_segment [0:(1 << ADDR_WIDTH)-1];


    // =====================================================
    // CPU WRITE ENCODER
    // =====================================================

    wire [12:0] encoded_din;

    ecc_encoder encoder (
        .din(din),
        .codeword(encoded_din)
    );


    // =====================================================
    // SCRUBBER ADDRESS
    // =====================================================

    reg [ADDR_WIDTH-1:0] scrub_addr;

    assign scrub_addr_debug = scrub_addr;


    // =====================================================
    // TWO READ PATHS
    // =====================================================

    wire [12:0] cpu_raw;
    wire [12:0] scrub_raw;

    assign cpu_raw =
        ram_segment[mem_addr];

    assign scrub_raw =
        ram_segment[scrub_addr];


    // =====================================================
    // CPU ECC DECODER
    //
    // CPU receives corrected 8-bit data immediately.
    // =====================================================

    wire [12:0] cpu_corrected;

    ecc_decoder cpu_decoder (
        .codeword(cpu_raw),

        .dout(dout),

        .single_error(cpu_single_error),
        .double_error(cpu_double_error),

        .corrected_codeword(cpu_corrected)
    );


    // =====================================================
    // SCRUBBER ECC DECODER
    //
    // This decoder produces the repaired 13-bit word.
    // =====================================================

    wire [7:0] scrub_dout;
    wire [12:0] scrub_corrected;

    ecc_decoder scrub_decoder (
        .codeword(scrub_raw),

        .dout(scrub_dout),

        .single_error(scrub_single_error),
        .double_error(scrub_double_error),

        .corrected_codeword(scrub_corrected)
    );


    // =====================================================
    // FAULT MASK
    // =====================================================

    wire valid_fault;
    wire [12:0] fault_mask;

    assign valid_fault =
        fault_inject &&
        (fault_bit < 4'd13);

    assign fault_mask =
        13'b1 << fault_bit;


    // =====================================================
    // WHEN SHOULD SCRUBBER REPAIR?
    //
    // Don't scrub while CPU is writing.
    // Don't scrub on the exact cycle we inject a fault.
    // =====================================================

    assign scrub_repair =
        scrub_enable &&
        !we &&
        !valid_fault &&
        scrub_single_error;


    // =====================================================
    // SCRUBBER ADDRESS COUNTER
    // =====================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            scrub_addr <= {ADDR_WIDTH{1'b0}};

            uncorrectable_seen <= 1'b0;

        end

        else begin

            // Only advance when RAM isn't busy with
            // CPU writing or deliberate fault injection.

            if (
                scrub_enable &&
                !we &&
                !valid_fault
            ) begin

                // Remember if SECDED finds an
                // uncorrectable two-bit error.

                if (scrub_double_error)
                    uncorrectable_seen <= 1'b1;


                // Move to next memory location.

                scrub_addr <= scrub_addr + 1'b1;

            end

        end

    end


    // =====================================================
    // MEMORY WRITES
    // =====================================================

    always @(posedge clk) begin


        // -------------------------------------------------
        // 1. CPU WRITE
        // -------------------------------------------------

        if (we) begin

            // Special case:
            //
            // CPU writes a new word AND an injected SEU
            // targets that exact same location.

            if (
                valid_fault &&
                (mem_addr == fault_index)
            ) begin

                ram_segment[mem_addr]
                    <= encoded_din ^ fault_mask;

            end

            else begin

                ram_segment[mem_addr]
                    <= encoded_din;

            end

        end


        // -------------------------------------------------
        // 2. FAULT INJECTION
        //
        // If fault is at another address, flip that
        // stored bit independently.
        // -------------------------------------------------

        if (
            valid_fault &&
            (
                !we ||
                (mem_addr != fault_index)
            )
        ) begin

            ram_segment[fault_index]
                <= ram_segment[fault_index]
                   ^ fault_mask;

        end


        // -------------------------------------------------
        // 3. MEMORY SCRUBBING
        //
        // Only happens if CPU isn't writing and we're
        // not deliberately injecting a fault.
        // -------------------------------------------------

        if (scrub_repair) begin

            ram_segment[scrub_addr]
                <= scrub_corrected;

        end

    end

endmodule