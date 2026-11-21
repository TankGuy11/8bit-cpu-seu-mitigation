module register_bank #(
    parameter WIDTH = 8
)(
    input wire            clk,
    input wire            gpr_we,
    input wire            reset,

    input wire[WIDTH-1:0] din,
    input wire[2:0]       dest_addr,

    input wire[2:0]       src1_addr,
    input wire[2:0]       src2_addr,
    input wire[2:0]       direct_addr,

    output wire[WIDTH-1:0] src1_out,
    output wire[WIDTH-1:0] src2_out,
    output wire[WIDTH-1:0] direct_out

);
    reg[WIDTH-1:0] regs [0:7];
    integer i;

    always@(posedge clk or posedge reset) begin
        if (reset == 1'b1) begin
            for (i = 0; i < 8; i = i + 1) begin
                regs[i] <= {{WIDTH{1'b0}}};
            end
        end else if(gpr_we == 1'b1) begin
            regs[dest_addr] <= din;
        end
    end
    assign src1_out = regs[src1_addr];
    assign src2_out = regs[src2_addr];
    assign direct_out = regs[direct_addr];
endmodule

