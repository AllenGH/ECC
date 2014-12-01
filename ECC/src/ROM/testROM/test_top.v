`timescale 100ns/1ns
module test_top();

   reg CLK ; 
   reg rst_n ;
   reg i_rd_rom,i_wr_rom ;
   reg [6:0] i_addr_rom ;
   reg [3:0] i_wordcnt_rom ;
   wire [15:0] o_data_rom_16bits ;
   wire [15:0] i_data_rom ;
   wire o_fifo_full_rom ;
   wire o_done_rom ;
   wire [15:0] Q ;
   wire CEN ;
   wire [6:0] A ;
   
Bimod_Tag_ROM    ROM(
  Q,
  CLK,
  CEN,
  A
   );
                
rominterface Rom_interface(
 	.clk(CLK)		,
  .rst_n(rst_n)	,
	.i_rd_rom(i_rd_rom)		,
	.i_wr_rom(i_wr_rom)		,
	.i_addr_rom(i_addr_rom) 		,
	.i_wordcnt_rom(i_wordcnt_rom),
	.i_data_rom (i_data_rom)	,
	.o_data_rom_16bits(o_data_rom_16bits)	,
	.o_fifo_full_rom(o_fifo_full_rom),	
	.o_done_rom(o_done_rom) ,
	.Q(Q),
	.CEN(CEN),
	.A(A)	
	);
	
   initial
   begin
    rst_n <=1'b0;
    i_rd_rom <= 1'b0 ;
    CLK<=1'b0;
    i_wr_rom <= 1'b0 ;
	i_addr_rom <= 8'h0 ;
	i_wordcnt_rom <= 8'h0 ;
  end
    always
    #5 CLK=~CLK;
    
    
   initial  begin
    #55  rst_n <= 1'h1 ;
    #11 i_addr_rom <= 7'h1 ; 
		i_rd_rom <= 1'b1 ;
        i_wordcnt_rom <= 8'h4 ;
 /*   #70 i_wordcnt_rom <= 8'h3 ;
        i_addr_rom    <= 8'h2 ;
    #70 i_wordcnt_rom <= 8'h2 ;
        i_addr_rom    <= 8'h4 ;
    #70 i_wordcnt_rom <= 8'h1;  
        i_addr_rom    <= 8'h6 ;
    #70 i_wordcnt_rom <= 8'h0 ; 
        i_addr_rom    <= 8'h6 ;
	#10 i_rd_rom <=1'b0 ;*/
    #200 $stop;
    end
  
   
   endmodule
