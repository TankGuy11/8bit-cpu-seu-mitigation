module ram #(
    parameter WIDTH = 8,
    parameter DEPTH = 256,
    parameter ADDR_WIDTH = 8
)(
    input wire                 clk,
    input wire                 we,
    input wire[ADDR_WIDTH-1:0] mem_addr,
    input wire[WIDTH-1:0]      din,
    output wire[WIDTH-1:0]     dout
);
    reg[WIDTH-1:0] ram_segment [0:DEPTH-1];
    always@(posedge clk) begin
        if(we == 1'b1) begin
            ram_segment[mem_addr] <= din;
        end
    end
    assign dout = ram_segment[mem_addr];
endmodule

        