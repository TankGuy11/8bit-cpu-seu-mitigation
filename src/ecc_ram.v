`timescale 1ns/1ps

module ecc_ram #(
    parameter ADDR_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  reset,          // RAM contents are intentionally preserved
    input  wire                  we,
    input  wire [ADDR_WIDTH-1:0] mem_addr,
    input  wire [7:0]            din,
    output wire [7:0]            dout,

    input  wire                  fault_inject,
    input  wire [ADDR_WIDTH-1:0] fault_index,
    input  wire [3:0]            fault_bit,

    output wire                  single_error,
    output wire                  double_error,
    output wire [12:0]           corrected_codeword
);

    reg [12:0] ram_segment [0:(1<<ADDR_WIDTH)-1];

    wire [12:0] encoded_word;
    wire [12:0] raw_word;
    wire        valid_fault;
    wire [12:0] fault_mask;

    // reset is intentionally not used to erase program/data RAM.
    wire unused_reset = reset;

    assign raw_word    = ram_segment[mem_addr];
    assign valid_fault = fault_inject && (fault_bit < 4'd13);
    assign fault_mask  = 13'b1 << fault_bit;

    ecc_encoder encoder (
        .din(din),
        .codeword(encoded_word)
    );

    ecc_decoder decoder (
        .codeword(raw_word),
        .dout(dout),
        .single_error(single_error),
        .double_error(double_error),
        .corrected_codeword(corrected_codeword)
    );

    always @(posedge clk) begin
        // Normal CPU/program write.
        if (we)
            ram_segment[mem_addr] <= encoded_word;

        // Deliberate SEU injection has priority if both occur together.
        if (valid_fault)
            ram_segment[fault_index] <=
                ram_segment[fault_index] ^ fault_mask;
    end

endmodule