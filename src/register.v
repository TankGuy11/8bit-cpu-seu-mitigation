module register #(
    parameter WIDTH = 8
)(
    input wire            clk,
    input wire            we,
    input wire            reset,
    input wire[WIDTH-1:0] din,
    output reg[WIDTH-1:0] dout 
);
    always@(posedge clk or posedge reset) begin
        if(reset == 1'b1) begin
            dout <= {WIDTH{1'b0}};
        end else if(we == 1'b1) begin
            dout <= din;
        end
    end
endmodule
