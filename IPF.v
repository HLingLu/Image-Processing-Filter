module IPF ( clk, reset, in_en, din, ipf_type, ipf_band_pos, ipf_wo_class, ipf_offset, lcu_x, lcu_y, lcu_size, busy, out_en, dout, dout_addr, finish);
input   clk;
input   reset;
input   in_en;
input   [7:0]  din;
input   [1:0]  ipf_type;
input   [4:0]  ipf_band_pos;
input          ipf_wo_class;
input   [15:0] ipf_offset;
input   [2:0]  lcu_x;
input   [2:0]  lcu_y;
input   [1:0]  lcu_size;
output  busy;
output  finish;
output  out_en;
output reg [7:0] dout;
output reg [13:0] dout_addr;

//====================== Parameter ==========================
parameter Prep = 3'd0, Po = 3'd1, Po_op = 3'd2, Wo_abc = 3'd3, Wo_op = 3'd4, Out = 3'd5, Init = 3'd6;
integer i;


//================= Reg/Wire Declaration ====================
reg [2:0] state, nxt_state;
reg [7:0] po_dout, wo_dout, nxt_po_dout, nxt_wo_dout, nxt_dout;
reg signed [8:0] sign_dout;
reg [13:0] addr_0, nxt_dout_addr;
reg [6:0] bound;
reg [7:0] row_a[0:63];
reg [7:0] row_b[0:63];
reg [7:0] row_c[0:63];
reg [7:0] nxt_row_a[0:63];
reg [7:0] nxt_row_b[0:63];
reg [7:0] nxt_row_c[0:63];
reg [7:0] pixel, nxt_pixel;
reg [6:0] out_col, nxt_out_col, out_row, nxt_out_row;
reg [6:0] in_cnt, nxt_in_cnt;
reg [4:0] band, nxt_band;
reg [7:0] row, row0, nxt_row, nxt_row0;
reg [7:0] col,  nxt_col;
reg [7:0] a, b, c;
reg [7:0] max, min;
reg [8:0] mean;
reg [1:0] type, nxt_type;
reg [4:0] band_pos, nxt_band_pos;
reg 	  wo_class, nxt_wo_class;
reg [15:0] offset, nxt_offset;
reg [5:0] lcu;
reg       ending, nxt_ending;

//================= Finite State Machine ====================
always@(*)begin
	case(state)
		Init:	begin
				nxt_state = Prep;
			end
		Prep:	begin
				case(ipf_type)
					2'd0: nxt_state = Out;
					2'd1: nxt_state = Po;
					2'd2: nxt_state = (ipf_wo_class) ? 
							  ((in_cnt < bound - 1'b1) ? Prep : (row == 6'b0) ? Wo_op : Wo_abc) : 
							  ((row == 6'b0 || row == bound + 1'b1) ? Wo_op : Wo_abc);
					default: nxt_state = Prep;
				endcase
			end
		Po:	begin
				nxt_state = Po_op;
			end
		Po_op:	begin
				nxt_state = Out;
			end
		Wo_abc: begin
				nxt_state = (wo_class) ? ((col < bound) ? Out : Wo_op) : Out;
			end
		Wo_op:	begin
				nxt_state = (row == bound - 1'b1 || dout_addr == 14'd16383) ? Wo_abc : Prep;
			end
		Out:	begin
				if(type == 2'd2) begin
					if(col != 7'b0 && wo_class) begin
						nxt_state = Wo_abc;
					end
					else if(row <= bound && !wo_class) begin
						nxt_state = Wo_op;
					end
					else begin
						nxt_state = Prep;
					end
				end
				else begin
					nxt_state = Prep;
				end
			end		
		default:begin
				nxt_state = Prep;
			end
	endcase
end 

always@(posedge clk or posedge reset)begin
	if(reset)begin
		state <= Init;
	end
	else begin
		state <= nxt_state;
	end
end


//==================== Sequential ===========================
always @(posedge clk or posedge reset) begin
	if(reset) begin
		bound <= 7'd16;
		addr_0 <= 14'b0;
	end
	else begin
		case(lcu_size)
			2'd0:	begin
					bound <= 7'd16;
					addr_0 <= ({11'b0, lcu_x[2:0]} << 4) + ({11'b0, lcu_y[2:0]} << 11);
				end
			2'd1:	begin
					bound <= 7'd32;
					addr_0 <= ({11'b0, lcu_x[2:0]} << 5) + ({11'b0, lcu_y[2:0]} <<12);
				end
			2'd2:	begin
					bound <= 7'd64;
					addr_0 <= ({11'b0, lcu_x[2:0]} << 6) + ({11'b0, lcu_y[2:0]} << 13);
				end
		     default:	begin
					bound <= 7'd0;
					addr_0 <= 14'b0;
				end
		endcase
	end
end

always @(posedge clk or posedge reset) begin
	if(reset) begin
		pixel <= 8'b0;
		type <= 2'b0;
		band_pos <= 5'b0;
		wo_class <= 1'b0;
		offset <= 16'b0;
		lcu <= 6'b0;
	end
	else begin
		pixel <= nxt_pixel;
		type <= nxt_type;
		band_pos <= nxt_band_pos;
		wo_class <= nxt_wo_class;
		offset <= nxt_offset;
		lcu <= {lcu_x[2:0], lcu_y[2:0]};
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		po_dout <= 8'b0;
		wo_dout <= 8'b0;
		dout <= 8'b0;
		dout_addr <= 14'b0;
		out_col <= 7'b0;
		out_row <= 7'b0;
		in_cnt <= 7'b0;
		row <= 7'b0;
		row0 <= 7'b0;
		col <= 7'b0;
		band <= 5'b0;
		ending <= 1'b0;
	end
	else begin
		po_dout <= nxt_po_dout;
		wo_dout <= nxt_wo_dout;
		dout <= nxt_dout;
		dout_addr <= nxt_dout_addr;
		out_col <= nxt_out_col;
		out_row <= nxt_out_row;
		in_cnt <= nxt_in_cnt;
		row <= nxt_row;
		row0 <= nxt_row0;
		col <= nxt_col;
		band <= nxt_band;
		ending <= nxt_ending;
	end
end

always @(posedge clk or posedge reset) begin
	if(reset) begin
		for(i = 0; i < 64; i = i + 1) begin
			row_a[i] <= 8'b0;
			row_b[i] <= 8'b0;
			row_c[i] <= 8'b0;
		end
	end
	else begin
		for(i = 0; i < 64; i = i + 1) begin
			row_a[i] <= nxt_row_a[i];
			row_b[i] <= nxt_row_b[i];
			row_c[i] <= nxt_row_c[i];
		end
	end
end

//==================== Combinational ========================
assign busy = (state == Prep || state == Init)? 1'b0 : 1'b1;
assign out_en = (state == Out)? 1'b1: 1'b0;
assign finish = (ending) ? 1'b1: 1'b0;

always @(*) begin
	if(state == Po) begin
		if(pixel >= 8'd0 && pixel < 8'd8) nxt_band = 5'd0;
		else if(pixel >= 8'd8 && pixel < 8'd16) nxt_band = 5'd1;
		else if(pixel >= 8'd16 && pixel < 8'd24) nxt_band = 5'd2;
		else if(pixel >= 8'd24 && pixel < 8'd32) nxt_band = 5'd3;
		else if(pixel >= 8'd32 && pixel < 8'd40) nxt_band = 5'd4;
		else if(pixel >= 8'd40 && pixel < 8'd48) nxt_band = 5'd5;
		else if(pixel >= 8'd48 && pixel < 8'd56) nxt_band = 5'd6;
		else if(pixel >= 8'd56 && pixel < 8'd64) nxt_band = 5'd7;
		else if(pixel >= 8'd64 && pixel < 8'd72) nxt_band = 5'd8;
		else if(pixel >= 8'd72 && pixel < 8'd80) nxt_band = 5'd9;
		else if(pixel >= 8'd80 && pixel < 8'd88) nxt_band = 5'd10;
		else if(pixel >= 8'd88 && pixel < 8'd96) nxt_band = 5'd11;
		else if(pixel >= 8'd96 && pixel < 8'd104) nxt_band = 5'd12;
		else if(pixel >= 8'd104 && pixel < 8'd112) nxt_band = 5'd13;
		else if(pixel >= 8'd112 && pixel < 8'd120) nxt_band = 5'd14;
		else if(pixel >= 8'd120 && pixel < 8'd128) nxt_band = 5'd15;
		else if(pixel >= 8'd128 && pixel < 8'd136) nxt_band = 5'd16;
		else if(pixel >= 8'd136 && pixel < 8'd144) nxt_band = 5'd17;
		else if(pixel >= 8'd144 && pixel < 8'd152) nxt_band = 5'd18;
		else if(pixel >= 8'd152 && pixel < 8'd160) nxt_band = 5'd19;
		else if(pixel >= 8'd160 && pixel < 8'd168) nxt_band = 5'd20;
		else if(pixel >= 8'd168 && pixel < 8'd176) nxt_band = 5'd21;
		else if(pixel >= 8'd176 && pixel < 8'd184) nxt_band = 5'd22;
		else if(pixel >= 8'd184 && pixel < 8'd192) nxt_band = 5'd23;
		else if(pixel >= 8'd192 && pixel < 8'd200) nxt_band = 5'd24;
		else if(pixel >= 8'd200 && pixel < 8'd208) nxt_band = 5'd25;
		else if(pixel >= 8'd208 && pixel < 8'd216) nxt_band = 5'd26;
		else if(pixel >= 8'd216 && pixel < 8'd224) nxt_band = 5'd27;
		else if(pixel >= 8'd224 && pixel < 8'd232) nxt_band = 5'd28;
		else if(pixel >= 8'd232 && pixel < 8'd240) nxt_band = 5'd29;
		else if(pixel >= 8'd240 && pixel < 8'd248) nxt_band = 5'd30;
		else nxt_band = 5'd31;
	end
	else begin
		nxt_band = band;
	end
end

always @(*) begin
	if(state == Po_op) begin
		if (band == band_pos - 1'b1 || band == band_pos || band == band_pos + 1'b1) begin
			nxt_po_dout = pixel;
		end
		else begin
			case(band)
				5'd0, 5'd4, 5'd8, 5'd12, 5'd16, 5'd20, 5'd24, 5'd28: 	begin
							sign_dout = $signed({1'b0, pixel[7:0]}) + $signed(offset[15:12]);
							nxt_po_dout = (sign_dout > 0) ? ((sign_dout < 255) ? 
								      sign_dout[7:0] : 9'd255) : 9'b0;
							end
				5'd1, 5'd5, 5'd9, 5'd13, 5'd17, 5'd21, 5'd25, 5'd29: 	begin
							sign_dout = $signed({1'b0, pixel[7:0]}) + $signed(offset[11:8]);
							nxt_po_dout = (sign_dout > 0) ? ((sign_dout < 255) ? 
								      sign_dout[7:0] : 9'd255) : 9'b0;
							end
				5'd2, 5'd6, 5'd10, 5'd14, 5'd18, 5'd22, 5'd26, 5'd30:	begin
							sign_dout = $signed({1'b0, pixel[7:0]}) + $signed(offset[7:4]);
							nxt_po_dout = (sign_dout > 0) ? ((sign_dout < 255) ? 
								      sign_dout[7:0] : 9'd255) : 9'b0;
							end
				5'd3, 5'd7, 5'd11, 5'd15, 5'd19, 5'd23, 5'd27, 5'd31:	begin
							sign_dout = $signed({1'b0, pixel[7:0]}) + $signed(offset[3:0]);
							nxt_po_dout = (sign_dout > 0) ? ((sign_dout < 255) ? 
								      sign_dout[7:0] : 9'd255) : 9'b0;
							end
					      default:	begin
							nxt_po_dout = {1'b0, pixel[7:0]};
							end
			endcase
		end
	end
	else begin
		nxt_po_dout = po_dout;
	end
end

always @(*) begin
	if(state == Wo_op) begin
		nxt_row = (wo_class) ? row + 1'b1 : ((row == bound) ? 7'b0 : row + 1'b1);
		nxt_row0 = (wo_class) ? row0 : ((row == 7'b0) ? row0 + 1'b1 : row0);
		for(i = 0; i < 64; i = i + 1) begin
			nxt_row_b[i] = row_a[i];
			nxt_row_c[i] = row_b[i];
		end
	end
	else begin
		nxt_row = (row <= bound) ? row : 7'b0;
		nxt_row0 = (row0 <= bound)? row0 : 7'b0;
		for(i = 0; i < 64; i = i + 1) begin
			nxt_row_b[i] = row_b[i];
			nxt_row_c[i] = row_c[i];
		end
	end
end

always @(*) begin
	if(state == Wo_abc) begin
		nxt_col = (wo_class) ? col + 1'b1 : 7'b0;
		if( col < bound && wo_class)begin
			a = row_a[col];
			b = row_c[col];
			c = row_b[col];
		end
		else if (!wo_class) begin
			a = row_a[0];
			b = row_c[0];
			c = row_b[0];
		end
		else begin
			a = 8'b0;
			b = 8'b0;
			c = 8'b0;
		end
		mean = (a + b) >> 1;
		if(a > b) begin
			max = a;
			min = b;
		end
		else begin
			max = b;
			min = a;
		end

		if(row == 7'b1 || row == bound) begin
			nxt_wo_dout = c;
		end
		else begin
			if(c < min) begin
				nxt_wo_dout = ((c + offset[15:12]) < 255) ? c + offset[15:12] : 8'd255;
			end
			else if(c > max) begin 
				sign_dout = $signed({1'b0, c[7:0]}) + $signed(offset[3:0]);
				nxt_wo_dout = (sign_dout > 0) ? sign_dout[7:0] : 8'b0;
			end
			else begin
				if(c < mean) begin
					nxt_wo_dout = ((c + offset[11:8]) < 255) ? c + offset[11:8] : 8'd255;
				end
				else if(c > mean) begin
					sign_dout = $signed({1'b0, c[7:0]}) + $signed(offset[7:4]);
					nxt_wo_dout = (sign_dout > 0) ? sign_dout[7:0] : 8'b0;
				end
				else begin
					nxt_wo_dout = c;
				end
			end
		end
	end
	else begin
		nxt_col = (col <= bound) ? col : 7'b0;
		a = 8'b0;
		b = 8'b0;
		c = 8'b0;
		mean = 8'b0;
		max = 8'b0;
		min = 8'b0;
		nxt_wo_dout = wo_dout;
	end
end

always @(*) begin
	if(state == Prep) begin
		nxt_pixel = din;
		nxt_type = ipf_type;
		nxt_band_pos = ipf_band_pos;
		nxt_wo_class = ipf_wo_class;
		nxt_offset = ipf_offset;
		for(i = 0; i < 64; i = i + 1) begin
			if(i == in_cnt) begin
				nxt_row_a[i] = (dout_addr[13:0] == 14'd16381)? pixel : din;
			end
			else begin
				nxt_row_a[i] = row_a[i];
			end
		end
		nxt_in_cnt = (in_en && ipf_type == 2'd2) ? (in_cnt + 1'b1) : 7'b0;
	end
	else begin
		nxt_pixel = pixel;
		nxt_type = type;
		nxt_band_pos = band_pos;
		nxt_wo_class = wo_class;
		nxt_offset = offset;
		for(i = 0; i < 64; i = i + 1) begin
			nxt_row_a[i] = row_a[i];
		end
		nxt_in_cnt = 7'b0;
	end
end

always @(*) begin
	if(state == Out)begin
//		$display("MEM[%d] = %d", dout_addr, dout);
		case(type)
			2'b0:	nxt_dout = pixel;
			2'b1:	nxt_dout = po_dout;
			2'b10:	nxt_dout = wo_dout;
		      default:	nxt_dout = dout;
		endcase
	
		if(out_col == 7'b0) begin
			nxt_dout_addr = addr_0;
			nxt_out_col = out_col + 1'b1;
			nxt_out_row = 7'b0;
		end
		else begin
			if(out_col < bound) begin
				nxt_dout_addr = dout_addr + 1'b1;
				nxt_out_col = out_col + 1'b1;
				nxt_out_row = out_row;
			end
			else begin
				nxt_dout_addr = (out_row < bound - 1'b1) ? (dout_addr + 8'd129 - bound) : addr_0;
				nxt_out_col = 7'b1;
				nxt_out_row = (out_row < bound - 1'b1) ? (out_row + 1'b1) : 7'b0;
			end
		end

		nxt_ending = (dout_addr == 14'd16383) ? 1'b1 : 1'b0;
	end
	else begin
		nxt_dout = dout;
		nxt_dout_addr = dout_addr;
		nxt_out_col = out_col;
		nxt_out_row = out_row;
		nxt_ending = 1'b0;
	end

end

endmodule

