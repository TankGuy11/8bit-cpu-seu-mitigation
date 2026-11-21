module ecc_encoder (
    input wire[7:0]   din,
    output wire[12:0] codeword
);
    wire [11:0] hamming;
    wire p1;
    wire p2;
    wire p4;
    wire p8;
    wire p0;
    assign p1 = din[0] ^ din[1] ^ din[3] ^ din[4] ^ din[6];
    assign p2 = din[0] ^ din[2] ^ din[3] ^ din[5] ^ din[6];
    assign p4 = din[1] ^ din[2] ^ din[3] ^ din[7];
    assign p8 = din[4] ^ din[5] ^ din[6] ^ din[7];

    assign hamming[0] = p1; 
    assign hamming[1] = p2;
    assign hamming[2] = din[0];
    assign hamming[3] = p4;
    assign hamming[4] = din[1];
    assign hamming[5] = din[2];
    assign hamming[6] = din[3];
    assign hamming[7] = p8;
    assign hamming[8] = din[4];
    assign hamming[9] = din[5];
    assign hamming[10] = din[6];
    assign hamming[11] = din[7];

    assign p0 = ^hamming;

    assign codeword = {p0, hamming};
endmodule