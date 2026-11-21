module pc #(
    parameter WIDTH = 8
)(
    input wire             clk,
    input wire             reset,
    input wire             pc_inc,
    input wire             pc_load,
    input wire[WIDTH-1:0]  jmp_addr,
    output reg[WIDTH-1:0]  pc_out
);
    always@(posedge clk or posedge reset) begin
        if(reset == 1'b1) begin
            pc_out <= {WIDTH{1'b0}};
        end else if(pc_load == 1'b1) begin
            pc_out <= jmp_addr;
        end else if(pc_inc == 1'b1) begin
            pc_out <= pc_out + 1'b1;
        end
    end
endmodule