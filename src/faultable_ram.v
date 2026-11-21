module faultable_ram #(
    parameter WIDTH = 8,
    parameter DEPTH = 256,
    parameter ADDR_WIDTH = 8
)(
    input wire                 clk,
    input wire                 we,
    input wire[ADDR_WIDTH-1:0] mem_addr,
    input wire                 fault_inject,
    input wire[ADDR_WIDTH-1:0] fault_index,
    input wire[2:0]            fault_bit,
    input wire[WIDTH-1:0]      din,
    output wire[WIDTH-1:0]     dout
);
    wire[WIDTH-1:0] fault_mask;
    assign fault_mask = {{(WIDTH-1){1'b0}}, 1'b1} << fault_bit;

    reg[WIDTH-1:0] ram_segment [0:DEPTH-1];
    always@(posedge clk) begin
        if(we == 1'b1) begin
            if(fault_inject && (mem_addr == fault_index)) begin
                ram_segment[mem_addr] <= din ^ fault_mask;
            end else begin 
                ram_segment[mem_addr] <= din;
            end
        end
        if(fault_inject && (!we || (mem_addr != fault_index))) begin
            ram_segment[fault_index] <= ram_segment[fault_index] ^ fault_mask;
        end
    end
    assign dout = ram_segment[mem_addr];
endmodule