module ecc_decoder(
    input wire[12:0] codeword,
    output wire[7:0] dout,

    output reg       single_error,
    output reg       double_error,

    output reg[12:0] corrected_codeword
);
    wire [11:0] hamming;

    wire s1;
    wire s2;
    wire s4;
    wire s8;

    wire [3:0] syndrome;

    wire overall_parity_error;

    assign hamming = codeword[11:0];

    assign s1 = hamming[0] ^ hamming[2] ^ hamming[4] ^ hamming[6] ^ hamming[8] ^ hamming[10];
    assign s2 = hamming[1] ^ hamming[2] ^ hamming[5] ^ hamming[6] ^ hamming[9] ^ hamming[10];
    assign s4 = hamming[3] ^ hamming[4] ^ hamming[5] ^ hamming[6] ^ hamming[11];
    assign s8 = hamming[7] ^ hamming[8] ^ hamming[9] ^ hamming[10] ^ hamming[11];

    assign syndrome = {s8, s4, s2, s1};

    assign overall_parity_error = ^codeword;

    always@(*) begin
        corrected_codeword = codeword;
        
        single_error = 1'b0;
        double_error = 1'b0;
        
        if((syndrome == 4'b0000)&&(overall_parity_error == 1'b0)) begin
            
        end else if ((syndrome != 4'b0000) && (overall_parity_error == 1'b1)) begin
            single_error = 1'b1;
            if(syndrome <= 4'd12) begin
                corrected_codeword[syndrome - 1'b1] = ~codeword[syndrome - 1'b1];
            end
        end else if(syndrome == 4'b0000 && overall_parity_error == 1'b1) begin
            single_error = 1'b1;
            corrected_codeword[12] = ~codeword[12];
        end else if(syndrome != 4'b0000 && overall_parity_error == 1'b0) begin
            double_error = 1'b1;
        end
    end

    assign dout[0] = corrected_codeword[2];
    assign dout[1] = corrected_codeword[4];
    assign dout[2] = corrected_codeword[5];
    assign dout[3] = corrected_codeword[6];
    assign dout[4] = corrected_codeword[8];
    assign dout[5] = corrected_codeword[9];
    assign dout[6] = corrected_codeword[10];
    assign dout[7] = corrected_codeword[11];

endmodule