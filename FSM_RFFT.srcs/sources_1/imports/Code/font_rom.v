`timescale 1ns / 1ps

//=============================================================================
// Module: font_rom
//
// 8x8 monochrome bitmap font ROM.
// Supports ASCII 0x20 (space) through 0x5A (Z): space, digits, uppercase.
//
// char_code: ASCII value (7-bit)
// row:       Row within character (0=top, 7=bottom)
// bitmap:    8 pixel bits for that row (bit[7]=leftmost pixel)
//
// Purely combinational — no clock required.
//=============================================================================

module font_rom (
    input  wire [6:0] char_code,    //which ASCII character (e.g., 7'h41 = 'A')
    input  wire [2:0] row,          //The character is 8 rows tall (row 0 to row 7).
    output reg  [7:0] bitmap        //8 pixels/bits for each row (bit[7]=leftmost pixel)    
);                                  //8x8 matrix per character, stored as 8 bytes/character in ROM 

    // ROM: indexed by (char_code - 0x20) * 8 + row
    // Supports chars 0x20..0x5A (91 entries × 8 rows = 728 bytes)
    reg [7:0] rom [0:727];  // 8 bits per row, 8 rows per char, 91 chars total

    integer i;
    initial begin
        // Default: all zeros
        for (i = 0; i < 728; i = i + 1) rom[i] = 8'h00; // Clear all entries

        // --- SPACE (0x20) ---
        rom[0*8+0]=8'h00; rom[0*8+1]=8'h00; rom[0*8+2]=8'h00; rom[0*8+3]=8'h00; // 8 rows of all zeros for space character
        rom[0*8+4]=8'h00; rom[0*8+5]=8'h00; rom[0*8+6]=8'h00; rom[0*8+7]=8'h00;

        // --- 0 (0x30 = index 16) ---
        rom[16*8+0]=8'h3C; rom[16*8+1]=8'h66; rom[16*8+2]=8'h6E; rom[16*8+3]=8'h76;     
        rom[16*8+4]=8'h66; rom[16*8+5]=8'h66; rom[16*8+6]=8'h3C; rom[16*8+7]=8'h00;

        // --- 1 (0x31 = index 17) ---
        rom[17*8+0]=8'h18; rom[17*8+1]=8'h38; rom[17*8+2]=8'h18; rom[17*8+3]=8'h18;
        rom[17*8+4]=8'h18; rom[17*8+5]=8'h18; rom[17*8+6]=8'h7E; rom[17*8+7]=8'h00;

        // --- 2 (0x32 = index 18) ---
        rom[18*8+0]=8'h3C; rom[18*8+1]=8'h66; rom[18*8+2]=8'h06; rom[18*8+3]=8'h0C;
        rom[18*8+4]=8'h18; rom[18*8+5]=8'h30; rom[18*8+6]=8'h7E; rom[18*8+7]=8'h00;

        // --- 3 (0x33 = index 19) ---
        rom[19*8+0]=8'h3C; rom[19*8+1]=8'h66; rom[19*8+2]=8'h06; rom[19*8+3]=8'h1C;
        rom[19*8+4]=8'h06; rom[19*8+5]=8'h66; rom[19*8+6]=8'h3C; rom[19*8+7]=8'h00;

        // --- 4 (0x34 = index 20) ---
        rom[20*8+0]=8'h06; rom[20*8+1]=8'h0E; rom[20*8+2]=8'h1E; rom[20*8+3]=8'h36;
        rom[20*8+4]=8'h7F; rom[20*8+5]=8'h06; rom[20*8+6]=8'h06; rom[20*8+7]=8'h00;

        // --- 5 (0x35 = index 21) ---
        rom[21*8+0]=8'h7E; rom[21*8+1]=8'h60; rom[21*8+2]=8'h7C; rom[21*8+3]=8'h06;
        rom[21*8+4]=8'h06; rom[21*8+5]=8'h66; rom[21*8+6]=8'h3C; rom[21*8+7]=8'h00;

        // --- 6 (0x36 = index 22) ---
        rom[22*8+0]=8'h1C; rom[22*8+1]=8'h30; rom[22*8+2]=8'h60; rom[22*8+3]=8'h7C;
        rom[22*8+4]=8'h66; rom[22*8+5]=8'h66; rom[22*8+6]=8'h3C; rom[22*8+7]=8'h00;

        // --- 7 (0x37 = index 23) ---
        rom[23*8+0]=8'h7E; rom[23*8+1]=8'h66; rom[23*8+2]=8'h0C; rom[23*8+3]=8'h18;
        rom[23*8+4]=8'h18; rom[23*8+5]=8'h18; rom[23*8+6]=8'h18; rom[23*8+7]=8'h00;

        // --- 8 (0x38 = index 24) ---
        rom[24*8+0]=8'h3C; rom[24*8+1]=8'h66; rom[24*8+2]=8'h66; rom[24*8+3]=8'h3C;
        rom[24*8+4]=8'h66; rom[24*8+5]=8'h66; rom[24*8+6]=8'h3C; rom[24*8+7]=8'h00;

        // --- 9 (0x39 = index 25) ---
        rom[25*8+0]=8'h3C; rom[25*8+1]=8'h66; rom[25*8+2]=8'h66; rom[25*8+3]=8'h3E;
        rom[25*8+4]=8'h06; rom[25*8+5]=8'h0C; rom[25*8+6]=8'h38; rom[25*8+7]=8'h00;

        // --- A (0x41 = index 33) ---
        rom[33*8+0]=8'h18; rom[33*8+1]=8'h3C; rom[33*8+2]=8'h66; rom[33*8+3]=8'h7E;
        rom[33*8+4]=8'h66; rom[33*8+5]=8'h66; rom[33*8+6]=8'h66; rom[33*8+7]=8'h00;

        // --- B (0x42 = index 34) ---
        rom[34*8+0]=8'h7C; rom[34*8+1]=8'h66; rom[34*8+2]=8'h66; rom[34*8+3]=8'h7C;
        rom[34*8+4]=8'h66; rom[34*8+5]=8'h66; rom[34*8+6]=8'h7C; rom[34*8+7]=8'h00;

        // --- C (0x43 = index 35) ---
        rom[35*8+0]=8'h3C; rom[35*8+1]=8'h66; rom[35*8+2]=8'h60; rom[35*8+3]=8'h60;
        rom[35*8+4]=8'h60; rom[35*8+5]=8'h66; rom[35*8+6]=8'h3C; rom[35*8+7]=8'h00;

        // --- D (0x44 = index 36) ---
        rom[36*8+0]=8'h78; rom[36*8+1]=8'h6C; rom[36*8+2]=8'h66; rom[36*8+3]=8'h66;
        rom[36*8+4]=8'h66; rom[36*8+5]=8'h6C; rom[36*8+6]=8'h78; rom[36*8+7]=8'h00;

        // --- E (0x45 = index 37) ---
        rom[37*8+0]=8'h7E; rom[37*8+1]=8'h60; rom[37*8+2]=8'h60; rom[37*8+3]=8'h7C;
        rom[37*8+4]=8'h60; rom[37*8+5]=8'h60; rom[37*8+6]=8'h7E; rom[37*8+7]=8'h00;

        // --- F (0x46 = index 38) ---
        rom[38*8+0]=8'h7E; rom[38*8+1]=8'h60; rom[38*8+2]=8'h60; rom[38*8+3]=8'h7C;
        rom[38*8+4]=8'h60; rom[38*8+5]=8'h60; rom[38*8+6]=8'h60; rom[38*8+7]=8'h00;

        // --- G (0x47 = index 39) ---
        rom[39*8+0]=8'h3C; rom[39*8+1]=8'h66; rom[39*8+2]=8'h60; rom[39*8+3]=8'h6E;
        rom[39*8+4]=8'h66; rom[39*8+5]=8'h66; rom[39*8+6]=8'h3C; rom[39*8+7]=8'h00;

        // --- H (0x48 = index 40) ---
        rom[40*8+0]=8'h66; rom[40*8+1]=8'h66; rom[40*8+2]=8'h66; rom[40*8+3]=8'h7E;
        rom[40*8+4]=8'h66; rom[40*8+5]=8'h66; rom[40*8+6]=8'h66; rom[40*8+7]=8'h00;

        // --- I (0x49 = index 41) ---
        rom[41*8+0]=8'h3C; rom[41*8+1]=8'h18; rom[41*8+2]=8'h18; rom[41*8+3]=8'h18;
        rom[41*8+4]=8'h18; rom[41*8+5]=8'h18; rom[41*8+6]=8'h3C; rom[41*8+7]=8'h00;

        // --- J (0x4A = index 42) ---
        rom[42*8+0]=8'h1E; rom[42*8+1]=8'h0C; rom[42*8+2]=8'h0C; rom[42*8+3]=8'h0C;
        rom[42*8+4]=8'h0C; rom[42*8+5]=8'h6C; rom[42*8+6]=8'h38; rom[42*8+7]=8'h00;

        // --- K (0x4B = index 43) ---
        rom[43*8+0]=8'h66; rom[43*8+1]=8'h6C; rom[43*8+2]=8'h78; rom[43*8+3]=8'h70;
        rom[43*8+4]=8'h78; rom[43*8+5]=8'h6C; rom[43*8+6]=8'h66; rom[43*8+7]=8'h00;

        // --- L (0x4C = index 44) ---
        rom[44*8+0]=8'h60; rom[44*8+1]=8'h60; rom[44*8+2]=8'h60; rom[44*8+3]=8'h60;
        rom[44*8+4]=8'h60; rom[44*8+5]=8'h60; rom[44*8+6]=8'h7E; rom[44*8+7]=8'h00;

        // --- M (0x4D = index 45) ---
        rom[45*8+0]=8'h63; rom[45*8+1]=8'h77; rom[45*8+2]=8'h7F; rom[45*8+3]=8'h6B;
        rom[45*8+4]=8'h63; rom[45*8+5]=8'h63; rom[45*8+6]=8'h63; rom[45*8+7]=8'h00;

        // --- N (0x4E = index 46) ---
        rom[46*8+0]=8'h66; rom[46*8+1]=8'h76; rom[46*8+2]=8'h7E; rom[46*8+3]=8'h7E;
        rom[46*8+4]=8'h6E; rom[46*8+5]=8'h66; rom[46*8+6]=8'h66; rom[46*8+7]=8'h00;

        // --- O (0x4F = index 47) ---
        rom[47*8+0]=8'h3C; rom[47*8+1]=8'h66; rom[47*8+2]=8'h66; rom[47*8+3]=8'h66;
        rom[47*8+4]=8'h66; rom[47*8+5]=8'h66; rom[47*8+6]=8'h3C; rom[47*8+7]=8'h00;

        // --- P (0x50 = index 48) ---
        rom[48*8+0]=8'h7C; rom[48*8+1]=8'h66; rom[48*8+2]=8'h66; rom[48*8+3]=8'h7C;
        rom[48*8+4]=8'h60; rom[48*8+5]=8'h60; rom[48*8+6]=8'h60; rom[48*8+7]=8'h00;

        // --- Q (0x51 = index 49) ---
        rom[49*8+0]=8'h3C; rom[49*8+1]=8'h66; rom[49*8+2]=8'h66; rom[49*8+3]=8'h66;
        rom[49*8+4]=8'h66; rom[49*8+5]=8'h3C; rom[49*8+6]=8'h0E; rom[49*8+7]=8'h00;

        // --- R (0x52 = index 50) ---
        rom[50*8+0]=8'h7C; rom[50*8+1]=8'h66; rom[50*8+2]=8'h66; rom[50*8+3]=8'h7C;
        rom[50*8+4]=8'h78; rom[50*8+5]=8'h6C; rom[50*8+6]=8'h66; rom[50*8+7]=8'h00;

        // --- S (0x53 = index 51) ---
        rom[51*8+0]=8'h3C; rom[51*8+1]=8'h66; rom[51*8+2]=8'h60; rom[51*8+3]=8'h3C;
        rom[51*8+4]=8'h06; rom[51*8+5]=8'h66; rom[51*8+6]=8'h3C; rom[51*8+7]=8'h00;

        // --- T (0x54 = index 52) ---
        rom[52*8+0]=8'h7E; rom[52*8+1]=8'h18; rom[52*8+2]=8'h18; rom[52*8+3]=8'h18;
        rom[52*8+4]=8'h18; rom[52*8+5]=8'h18; rom[52*8+6]=8'h18; rom[52*8+7]=8'h00;

        // --- U (0x55 = index 53) ---
        rom[53*8+0]=8'h66; rom[53*8+1]=8'h66; rom[53*8+2]=8'h66; rom[53*8+3]=8'h66;
        rom[53*8+4]=8'h66; rom[53*8+5]=8'h66; rom[53*8+6]=8'h3C; rom[53*8+7]=8'h00;

        // --- V (0x56 = index 54) ---
        rom[54*8+0]=8'h66; rom[54*8+1]=8'h66; rom[54*8+2]=8'h66; rom[54*8+3]=8'h66;
        rom[54*8+4]=8'h66; rom[54*8+5]=8'h3C; rom[54*8+6]=8'h18; rom[54*8+7]=8'h00;

        // --- W (0x57 = index 55) ---
        rom[55*8+0]=8'h63; rom[55*8+1]=8'h63; rom[55*8+2]=8'h63; rom[55*8+3]=8'h6B;
        rom[55*8+4]=8'h7F; rom[55*8+5]=8'h77; rom[55*8+6]=8'h63; rom[55*8+7]=8'h00;

        // --- X (0x58 = index 56) ---
        rom[56*8+0]=8'h66; rom[56*8+1]=8'h66; rom[56*8+2]=8'h3C; rom[56*8+3]=8'h18;
        rom[56*8+4]=8'h3C; rom[56*8+5]=8'h66; rom[56*8+6]=8'h66; rom[56*8+7]=8'h00;

        // --- Y (0x59 = index 57) ---
        rom[57*8+0]=8'h66; rom[57*8+1]=8'h66; rom[57*8+2]=8'h66; rom[57*8+3]=8'h3C;
        rom[57*8+4]=8'h18; rom[57*8+5]=8'h18; rom[57*8+6]=8'h18; rom[57*8+7]=8'h00;

        // --- Z (0x5A = index 58) ---
        rom[58*8+0]=8'h7E; rom[58*8+1]=8'h06; rom[58*8+2]=8'h0C; rom[58*8+3]=8'h18;
        rom[58*8+4]=8'h30; rom[58*8+5]=8'h60; rom[58*8+6]=8'h7E; rom[58*8+7]=8'h00;
    end

    always @(*) begin
        if (char_code >= 7'h20 && char_code <= 7'h5A)
            bitmap = rom[(char_code - 7'h20) * 8 + row];    
        else
            bitmap = 8'h00;
    end

endmodule
