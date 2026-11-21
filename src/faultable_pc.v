module faultable_pc #(
    parameter WIDTH = 8
)(
    input wire                clk,
    input wire                pc_inc,
    input wire                pc_load,
    input wire[WIDTH-1:0]     jmp_addr,
    input wire                reset,
    input wire                fault_inject,
    input wire[2:0]           fault_bit,
    output reg[WIDTH-1:0]     pc_out
);
    wire[WIDTH-1:0] fault_mask;
    assign fault_mask = {{(WIDTH-1){1'b0}}, 1'b1} << fault_bit;

    always@(posedge clk or posedge reset) begin
        if(reset) begin
            pc_out <= {WIDTH{1'b0}};
        end else if(pc_load && fault_inject) begin
            pc_out <= jmp_addr ^ fault_mask;
        end else if(pc_inc && fault_inject) begin
            pc_out <= (pc_out + 1'b1) ^ fault_mask;
        end else if(fault_inject) begin
            pc_out <= pc_out ^ fault_mask;
        end else if(pc_load == 1'b1) begin
            pc_out <= jmp_addr;
        end else if(pc_inc == 1'b1) begin
            pc_out <= pc_out + {{(WIDTH-1){1'b0}}, 1'b1};
        end
    end
endmodule
