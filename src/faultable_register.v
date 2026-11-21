module faultable_register #(
    parameter WIDTH = 8
)(
    input wire             clk,
    input wire             we,
    input wire             reset,
    input wire             fault_inject,
    input wire[2:0]        fault_bit,
    input wire[WIDTH-1:0]        din,
    output reg[WIDTH-1:0]        dout
);
    wire[WIDTH-1:0] fault_mask;
    assign fault_mask = {{(WIDTH-1){1'b0}}, 1'b1} << fault_bit;

    always@(posedge clk or posedge reset) begin
        if(reset) begin
            dout <= {WIDTH{1'b0}};
        end else if(we && fault_inject) begin
            dout <= din ^ fault_mask;
        end else if(fault_inject == 1'b1) begin
            dout <= dout ^ fault_mask;
        end else if(we == 1'b1) begin
            dout <= din;
        end
    end
endmodule