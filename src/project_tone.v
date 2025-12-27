//with tone or audio
`default_nettype none

module tt_um_HappyNewYear2026 (
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena, clk, rst_n
);

    // --- REFINED AUDIO ENGINE ---
    reg [17:0] tone_counter;
    reg [17:0] tone_period;
    reg [24:0] duration_counter;
    reg [4:0]  note_index;
    reg        speaker;

    // Frequencies for 25.175 MHz clock
    localparam G3=18'd64222, A3=18'd57216, C4=18'd48112, D4=18'd42861, E4=18'd38187, G4=18'd32111, A4=18'd28608, SIL=18'd0;

    always @(posedge clk) begin
        if (~rst_n) begin
            note_index <= 0; duration_counter <= 0;
            tone_counter <= 0; speaker <= 0; tone_period <= SIL;
        end else begin
            duration_counter <= duration_counter + 1'b1;
            
            // Note duration (approx 0.2s)
            if (duration_counter == 25'd5_035_000) begin 
                duration_counter <= 0;
                note_index <= note_index + 1'b1;
            end

            // Synchronous Note Selection to prevent "Gargling"
            case (note_index)
                0:  tone_period <= G3; 
                1,2,3: tone_period <= C4; 4: tone_period <= E4; 5: tone_period <= D4; 
                6:  tone_period <= C4; 7:  tone_period <= D4;
                8,9: tone_period <= E4; 10: tone_period <= C4; 11: tone_period <= E4; 
                12: tone_period <= G4; 13,14: tone_period <= A4; 15: tone_period <= SIL;
                16: tone_period <= A4; 17: tone_period <= G4; 18,19: tone_period <= E4; 
                20: tone_period <= C4; 21: tone_period <= D4; 22: tone_period <= C4; 23: tone_period <= D4;
                24: tone_period <= E4; 25: tone_period <= C4; 26,27: tone_period <= A3; 
                28: tone_period <= G3; 29,30: tone_period <= C4; 31: tone_period <= SIL;
                default: tone_period <= SIL;
            endcase

            // Tone Generation Logic with Clean Cutoff
            // The "4_500_000" threshold creates a tiny gap of silence between notes
            if (tone_period == SIL || duration_counter > 25'd4_500_000) begin
                speaker <= 0;
                tone_counter <= 0;
            end else begin
                if (tone_counter >= tone_period) begin
                    tone_counter <= 0;
                    speaker <= ~speaker;
                end else begin
                    tone_counter <= tone_counter + 1'b1;
                end
            end
        end
    end

    // --- VGA SIGNALS ---
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    reg [1:0] R_wire, G_wire, B_wire;

    assign uo_out = {hsync, B_wire[0], G_wire[0], R_wire[0], vsync, B_wire[1], G_wire[1], R_wire[1]};
    assign uio_out = {speaker, 7'b0}; 
    assign uio_oe  = 8'b10000000; 

    hvsync_generator hvsync_gen(.clk(clk), .reset(~rst_n), .hsync(hsync), .vsync(vsync), .display_on(video_active), .hpos(pix_x), .vpos(pix_y));

    // --- STABLE DVD BOUNCING ---
    reg [9:0] pos_x, pos_y;
    reg dir_x, dir_y; 
    reg [2:0] color_index; 
    localparam [9:0] TEXT_W = 560; // 20 * 28
    localparam [9:0] MAX_X  = 640 - TEXT_W;
    localparam [9:0] MAX_Y  = 480 - 32;

    always @(posedge clk) begin
        if (~rst_n) begin
            pos_x <= 10; pos_y <= 10; dir_x <= 0; dir_y <= 0; color_index <= 3'd1;
        end else if (pix_x == 0 && pix_y == 480) begin
            if (pos_x >= MAX_X) begin dir_x <= 1; color_index <= color_index + 1'b1; end
            else if (pos_x <= 1) begin dir_x <= 0; color_index <= color_index + 1'b1; end
            if (pos_y >= MAX_Y) begin dir_y <= 1; color_index <= color_index + 1'b1; end
            else if (pos_y <= 1) begin dir_y <= 0; color_index <= color_index + 1'b1; end
            pos_x <= dir_x ? pos_x - 1 : pos_x + 1;
            pos_y <= dir_y ? pos_y - 1 : pos_y + 1;
        end
    end

    // --- RENDERING ---
    wire [9:0] lx = pix_x - pos_x;
    wire [9:0] ly = pix_y - pos_y;
    wire in_text = (pix_x >= pos_x && pix_x < pos_x + TEXT_W) && (pix_y >= pos_y && pix_y < pos_y + 32);
    
    reg [7:0] bitmap;
    wire [2:0] row = ly[4:2]; 
    always @(*) begin
        case (lx / 28)
            0: bitmap = (row==3||row==4) ? 8'b11111100 : 8'b11001100; // H
            1: case(row) 0,1: bitmap=8'b01111000; 3,4: bitmap=8'b11111100; default: bitmap=8'b11001100; endcase // A
            2,3: case(row) 0,1,3,4: bitmap=8'b11111100; 2: bitmap=8'b11001100; default: bitmap=8'b11000000; endcase // P
            4: case(row) 0,1: bitmap=8'b11000110; 2: bitmap=8'b01101100; default: bitmap=8'b00111000; endcase // Y
            6: case(row) 0: bitmap=8'b11001100; 1: bitmap=8'b11101100; 2: bitmap=8'b11111100; 3: bitmap=8'b11011100; default: bitmap=8'b11001100; endcase // N
            7: bitmap = (row==2||row==5) ? 8'b11000000 : 8'b11111100; // E
            8: case(row) 0,1,2,3: bitmap=8'b11000110; 4,5: bitmap=8'b11010110; 6: bitmap=8'b11111110; 7: bitmap=8'b01101100; default: bitmap=8'b11000110; endcase // W
            10: case(row) 0,1: bitmap=8'b11000110; 2: bitmap=8'b01101100; default: bitmap=8'b00111000; endcase // Y
            11: bitmap = (row==2||row==5) ? 8'b11000000 : 8'b11111100; // E
            12: case(row) 0,1: bitmap=8'b01111000; 3,4: bitmap=8'b11111100; default: bitmap=8'b11001100; endcase // A
            13: case(row) 0,1,3,4: bitmap=8'b11111100; 2: bitmap=8'b11001100; 5: bitmap=8'b11110000; 6: bitmap=8'b11011000; default: bitmap=8'b11001100; endcase // R
            15: case(row) 0,1,3,4,6,7: bitmap=8'b11111100; 2: bitmap=8'b00001100; 5: bitmap=8'b11000000; default: bitmap=0; endcase // 2
            16: bitmap = (row==0||row==1||row==6||row==7) ? 8'b01111000 : 8'b11001100; // 0
            17: case(row) 0,1,3,4,6,7: bitmap=8'b11111100; 2: bitmap=8'b00001100; 5: bitmap=8'b11000000; default: bitmap=0; endcase // 2
            18: case(row) 0,1,3,4,6,7: bitmap=8'b11111100; 2: bitmap=8'b11000000; 5: bitmap=8'b11001100; default: bitmap=0; endcase // 6
            19: bitmap = (row==5) ? 0 : 8'b01110000; // !
            default: bitmap = 0;
        endcase
    end

    wire pixel = in_text && bitmap[7 - ((lx % 28) * 8 / 28)];

    always @(*) begin
        if (!video_active) begin
            {R_wire, G_wire, B_wire} = 6'b000000;
        end else if (pixel) begin
            case(color_index)
                3'd0: {R_wire, G_wire, B_wire} = 6'b111111; 
                3'd1: {R_wire, G_wire, B_wire} = 6'b111100; 
                3'd2: {R_wire, G_wire, B_wire} = 6'b110011; 
                3'd3: {R_wire, G_wire, B_wire} = 6'b001111; 
                3'd4: {R_wire, G_wire, B_wire} = 6'b110000; 
                3'd5: {R_wire, G_wire, B_wire} = 6'b001100; 
                3'd6: {R_wire, G_wire, B_wire} = 6'b100111; 
                default: {R_wire, G_wire, B_wire} = 6'b111001; 
            endcase
        end else begin
            {R_wire, G_wire, B_wire} = 6'b000001;
        end
    end

endmodule
