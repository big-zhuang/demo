`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/05/11 16:17:41
// Design Name: 
// Module Name: Ctrl_Spi_Master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ctrl_spi_master(
	input									spi_clk,
	input									spi_reset,
	input 									spi_sel,
	input									spi_wr_en,
	input									spi_rd_en,
	input[1-1:0]			spi_cmd,
	input[15-1:0]			spi_addr,
	input[8-1:0]			spi_din,
	output reg[8-1:0]	spi_dout,
	output reg 						spi_finish,
	////////////////////
	output reg 						spi_cs_n,
	output 								spi_sclk,
	input 									spi_sdo, 
	inout 									spi_sdio	
    );
	


reg[1:0]				spi_wr_en_d;
wire 						spi_wr_en_pos;

reg[1:0]				spi_rd_en_d;
wire 						spi_rd_en_pos;

reg 							spi_sdi;
reg 							spi_wr_sel; 
reg 							rd_data_valid;
reg[4:0]				bit_cout;
reg[4:0]				spi_state;

reg[8-1:0]	spi_rdata =0;

localparam IDLE					=5'b0_0001;
localparam WRITE_CMD			=5'b0_0010;
localparam WRITE_ADDR		=5'b0_0100;
localparam WRITE_DATA		=5'b0_1000;
localparam RECEIVE_DATA	=5'b1_0000;
////////////////////////////////////////////edge check
always@(negedge spi_clk)
begin
	if(spi_reset)
		spi_wr_en_d <=2'b00;
	 else 
		spi_wr_en_d <={spi_wr_en_d[0],spi_wr_en};
end
		
assign spi_wr_en_pos =spi_wr_en_d[0] & ~spi_wr_en_d[1];	

always@(negedge spi_clk)
begin
	if(spi_reset)
		spi_rd_en_d <=2'b00;
	 else 
		spi_rd_en_d <={spi_rd_en_d[0],spi_rd_en};
end
		
assign spi_rd_en_pos =spi_rd_en_d[0] & ~spi_rd_en_d[1];	
//////////////////////////////////////////////spi state machine
always@(negedge spi_clk)
begin
	if(spi_reset)
	begin
		spi_cs_n 			<=1'b1;
		spi_sdi 				<=1'b0;
		spi_finish 		<=1'b0;
		rd_data_valid 	<=1'b0;
		bit_cout 			<=5'd0;
		spi_wr_sel 		<=1'b0;
		spi_state 			<=IDLE;
	end 
	else
	begin	
		case(spi_state)
		IDLE:
		begin
			spi_cs_n 			<=1'b1;
			spi_sdi 				<=1'b0;
			spi_finish 		<=1'b0;
			rd_data_valid	<=1'b0;
			bit_cout 			<=5'd0;	
			if(spi_rd_en_pos)
				spi_wr_sel 	<=1'b1;						//0:write 1:read
			else
				spi_wr_sel 	<=1'b0;
			if(spi_wr_en_pos || spi_rd_en_pos)
				spi_state 		<=WRITE_CMD;	
		end 
				
		WRITE_CMD:
		begin
			spi_cs_n	<=1'b0;
			spi_sdi 		<=spi_cmd[1-1-bit_cout];
			bit_cout 	<=bit_cout + 1'b1;
			if(bit_cout ==(1-1))
			begin
				bit_cout 	<=5'd0;
				spi_state 	<=WRITE_ADDR;
			end
		end
				
		WRITE_ADDR:	
		begin
			spi_cs_n	<=1'b0;
			spi_sdi 		<=spi_addr[15-1-bit_cout];
			bit_cout 	<=bit_cout + 1'b1;
			if(bit_cout ==(15-1))
			begin
				bit_cout 		<=5'd0;
				if(~spi_wr_sel)
					spi_state	<=WRITE_DATA;
				else	
					spi_state 	<=RECEIVE_DATA;
			end
		end
				
		WRITE_DATA:
		begin
			spi_cs_n	<=1'b0;
			spi_sdi 		<=spi_din[8-1-bit_cout];
			bit_cout 	<=bit_cout + 1'b1;
			if(bit_cout ==(8-1))
			begin
				bit_cout 		<=5'd0;
				spi_finish	<=1'b1;
				spi_state 		<=IDLE;
			end		
		end
				
		RECEIVE_DATA:	
		begin
			rd_data_valid	<=1'b1;
			bit_cout 			<=bit_cout + 1'b1;
			if(bit_cout ==(8-1))
			begin
				bit_cout 		<=5'd0;
				spi_finish	<=1'b1;
				spi_state 		<=IDLE;
			end
		end
		
		default:spi_state <=IDLE;
		endcase
	end
end
/////////////////////////////////////////////////////////read data
always@(posedge spi_clk)
begin
	if(rd_data_valid)
	begin
		if(spi_sel)
			spi_rdata <={spi_rdata[8-2:0],spi_sdo};
		else
			spi_rdata <={spi_rdata[8-2:0],spi_sdio}; 
	end
	else
		spi_dout <=spi_rdata;
end
/////////////////////////////////////////////////////phy
assign spi_sdio =(~spi_cs_n &&  ~rd_data_valid) ? spi_sdi : 1'bz;
assign spi_sclk =~spi_cs_n ? spi_clk : 1'b0;

endmodule
