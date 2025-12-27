//original Verilog without tone or audio
`default_nettype none

module tt_um_HappyNewYear2026(
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena, clk, rst_n
);

    // VGA signals
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    reg [1:0] R_wire, G_wire, B_wire;

    assign uo_out = {hsync, B_wire[0], G_wire[0], R_wire[0], vsync, B_wire[1], G_wire[1], R_wire[1]};
    assign uio_out = 0;
    assign uio_oe  = 0;

    hvsync_generator hvsync_gen(
        .clk(clk), .reset(~rst_n),
        .hsync(hsync), .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x), .vpos(pix_y)
    );

    // --- BOUNCING & COLOR STATE ---
    reg [9:0] pos_x, pos_y;
    reg dir_x, dir_y; 
    reg [2:0] color_index; 

    localparam [9:0] CHAR_W = 28; 
    localparam [9:0] TEXT_W = 20 * CHAR_W; 
    localparam [9:0] TEXT_H = 32;
    localparam [9:0] MAX_X  = 640 - TEXT_W;
    localparam [9:0] MAX_Y  = 480 - TEXT_H;

    wire update_frame = (pix_x == 0 && pix_y == 480);

    always @(posedge clk) begin
        if (~rst_n) begin
            pos_x <= 10; pos_y <= 10;
            dir_x <= 0;  dir_y <= 0;
            color_index <= 3'd1;
        end else if (update_frame) begin
            if (pos_x >= MAX_X) begin dir_x <= 1; color_index <= color_index + 1'b1; end
            else if (pos_x <= 1) begin dir_x <= 0; color_index <= color_index + 1'b1; end

            if (pos_y >= MAX_Y) begin dir_y <= 1; color_index <= color_index + 1'b1; end
            else if (pos_y <= 1) begin dir_y <= 0; color_index <= color_index + 1'b1; end

            pos_x <= dir_x ? pos_x - 1 : pos_x + 1;
            pos_y <= dir_y ? pos_y - 1 : pos_y + 1;
        end
    end

    // --- RENDERING ---
    wire in_text = (pix_x >= pos_x && pix_x < pos_x + TEXT_W) &&
                   (pix_y >= pos_y && pix_y < pos_y + TEXT_H);

    wire [9:0] lx = pix_x - pos_x;
    wire [9:0] ly = pix_y - pos_y;
    wire [4:0] char_idx = lx / CHAR_W; 
    
    reg [7:0] ascii;
    always @(*) begin
        case (char_idx)
            0: ascii = "H"; 1: ascii = "A"; 2: ascii = "P"; 3: ascii = "P"; 4: ascii = "Y";
            5: ascii = " "; 6: ascii = "N"; 7: ascii = "E"; 8: ascii = "W"; 9: ascii = " ";
            10:ascii = "Y"; 11:ascii = "E"; 12:ascii = "A"; 13:ascii = "R"; 14:ascii = " ";
            15:ascii = "2"; 16:ascii = "0"; 17:ascii = "2"; 18:ascii = "6"; 19:ascii = "!";
            default: ascii = " ";
        endcase
    end

    // --- BOLD ROM WITH REFINED Y ---
    reg [7:0] bitmap;
    wire [2:0] row = ly[4:2]; 
    always @(*) begin
        case (ascii)
            "H": case(row) 3,4: bitmap = 8'b11111100; default: bitmap = 8'b11001100; endcase
            "A": case(row) 0,1: bitmap = 8'b01111000; 3,4: bitmap = 8'b11111100; default: bitmap = 8'b11001100; endcase
            "P": case(row) 0,1,3,4: bitmap = 8'b11111100; 2: bitmap = 8'b11001100; default: bitmap = 8'b11000000; endcase
            
            // --- REFINED Y ---
            "Y": case(row)
                    0,1:     bitmap = 8'b11000110; // Wide top
                    2:       bitmap = 8'b01101100; // Moving inward
                    3,4,5,6: bitmap = 8'b00111000; // Strong center stem
                    default: bitmap = 8'b00111000;
                 endcase

            "N": case(row) 0: bitmap = 8'b11001100; 1: bitmap = 8'b11101100; 2: bitmap = 8'b11111100; 3: bitmap = 8'b11011100; default: bitmap = 8'b11001100; endcase
            "E": case(row) 0,1,3,4,6,7: bitmap = 8'b11111100; default: bitmap = 8'b11000000; endcase
            "W": case(row) 0,1,2,3: bitmap = 8'b11000110; 4,5: bitmap = 8'b11010110; 6: bitmap = 8'b11111110; 7: bitmap = 8'b01101100; default: bitmap = 8'b11000110; endcase
            "R": case(row) 0,1,3,4: bitmap = 8'b11111100; 2: bitmap = 8'b11001100; 5: bitmap = 8'b11110000; 6: bitmap = 8'b11011000; default: bitmap = 8'b11001100; endcase
            "2": case(row) 0,1,3,4,6,7: bitmap = 8'b11111100; 2: bitmap = 8'b00001100; 5: bitmap = 8'b11000000; default: bitmap = 0; endcase
            "0": case(row) 0,1,6,7: bitmap = 8'b01111000; default: bitmap = 8'b11001100; endcase
            "6": case(row) 0,1,3,4,6,7: bitmap = 8'b11111100; 2: bitmap = 8'b11000000; 5: bitmap = 8'b11001100; default: bitmap = 0; endcase
            "!": case(row) 0,1,2,3,4: bitmap = 8'b01110000; 6,7: bitmap = 8'b01110000; default: bitmap = 0; endcase
            default: bitmap = 0;
        endcase
    end

    wire [4:0] x_pixel = (lx % CHAR_W) * 8 / CHAR_W;
    wire pixel = in_text && bitmap[7 - x_pixel];

    // --- COLOR TABLE ---
    always @(*) begin
        if (!video_active) begin
            R_wire = 2'b00; G_wire = 2'b00; B_wire = 2'b00;
        end else if (pixel) begin
            case(color_index)
                3'd0: begin R_wire = 2'b11; G_wire = 2'b11; B_wire = 2'b11; end 
                3'd1: begin R_wire = 2'b11; G_wire = 2'b11; B_wire = 2'b00; end 
                3'd2: begin R_wire = 2'b11; G_wire = 2'b00; B_wire = 2'b11; end 
                3'd3: begin R_wire = 2'b00; G_wire = 2'b11; B_wire = 2'b11; end 
                3'd4: begin R_wire = 2'b11; G_wire = 2'b00; B_wire = 2'b00; end 
                3'd5: begin R_wire = 2'b00; G_wire = 2'b11; B_wire = 2'b00; end 
                3'd6: begin R_wire = 2'b10; G_wire = 2'b01; B_wire = 2'b11; end 
                3'd7: begin R_wire = 2'b11; G_wire = 2'b10; B_wire = 2'b01; end 
            endcase
        end else begin
            R_wire = 2'b00; G_wire = 2'b00; B_wire = 2'b01;
        end
    end

endmodule
