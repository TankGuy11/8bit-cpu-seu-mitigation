module faultable_register_bank #(
    parameter WIDTH = 8
)(
    input wire                 clk,
    input wire                 reset,

    input wire                 we,
    input wire [WIDTH-1:0]     din,
    input wire [2:0]           dest_addr,

    input wire [2:0]           src1_addr,
    input wire [2:0]           src2_addr,
    input wire [2:0]           direct_addr,

    input wire                 fault_inject,
    input wire [2:0]           fault_index,
    input wire [2:0]           fault_bit,

    output wire [WIDTH-1:0]    src1_out,
    output wire [WIDTH-1:0]    src2_out,
    output wire [WIDTH-1:0]    direct_out
);

    reg [WIDTH-1:0] regs [0:7];

    wire [WIDTH-1:0] fault_mask;

    integer i;


    assign fault_mask =
        {{(WIDTH-1){1'b0}}, 1'b1} << fault_bit;


    always @(posedge clk or posedge reset) begin

        if (reset) begin

            for (i = 0; i < 8; i = i + 1)
                regs[i] <= {WIDTH{1'b0}};

        end

        else begin

            // =============================================
            // NORMAL WRITE
            // =============================================

            if (we) begin

                // Writing and faulting SAME register
                if (
                    fault_inject &&
                    (dest_addr == fault_index)
                ) begin

                    regs[dest_addr] <=
                        din ^ fault_mask;

                end

                // Normal write
                else begin

                    regs[dest_addr] <= din;

                end

            end


            // =============================================
            // FAULT INJECTION
            //
            // Only do this separately if we did NOT already
            // handle the fault in the write-above case.
            // =============================================

            if (
                fault_inject &&
                (!we || (dest_addr != fault_index))
            ) begin

                regs[fault_index] <=
                    regs[fault_index] ^ fault_mask;

            end

        end

    end


    // =============================================
    // ASYNCHRONOUS READ PORTS
    // =============================================

    assign src1_out =
        regs[src1_addr];

    assign src2_out =
        regs[src2_addr];

    assign direct_out =
        regs[direct_addr];


endmodule