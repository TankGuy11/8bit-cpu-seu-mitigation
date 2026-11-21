module alu #(
    parameter WIDTH = 8
)(
    input wire[2:0]       alu_opcodes,
    input wire[WIDTH-1:0] a,
    input wire[WIDTH-1:0] b,
    output reg[WIDTH-1:0] alu_out,
    output reg            zero,
    output reg            carry,
    output reg            underflow
);
    always@(*) begin
        alu_out = {WIDTH{1'b0}};
        zero = 1'b0;
        carry = 1'b0;
        underflow = 1'b0;

        case(alu_opcodes) 
            3'b000: begin
                {carry, alu_out} = {1'b0, a} + {1'b0, b};
            end
            3'b001: begin
                alu_out = a - b;
                if(a >= b) begin
                    carry = 1'b1;
                    underflow = 1'b0;
                end else begin 
                    carry = 1'b0;
                    underflow = 1'b1;
                end
            end
            3'b010: begin 
                {carry, alu_out} ={1'b0, a} + {{WIDTH{1'b0}}, 1'b1};
            end
            3'b011: begin
                alu_out = a - {{(WIDTH-1){1'b0}}, 1'b1};
                if(a == 8'h00) begin
                    carry = 1'b0;
                    underflow = 1'b1;
                end else begin
                    carry = 1'b1;
                    underflow = 1'b0;
                end
            end
            3'b100: begin
                alu_out = a & b;
            end
            3'b101: begin
                alu_out = a ^ b;
            end
            3'b110: begin
                alu_out = {a[WIDTH-2:0], 1'b0};
            end
            3'b111: begin
                alu_out = {1'b0, a[WIDTH-1:1]};
            end
            default: begin
                alu_out = {WIDTH{1'b0}};
            end
        endcase
        if(alu_out == {WIDTH{1'b0}}) begin
            zero = 1'b1;
        end else begin 
            zero = 1'b0;
        end
    end
endmodule