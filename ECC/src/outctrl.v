`timescale 1ns/100ps

module outctrl	(
	clk		,
	rst_n	,
	i_ACK_dec	,
	//---------added by lhzhu----------//
	i_Authenticate_dec  ,
	i_Authenticate_step_cu   ,
	i_data_rom_16bits	,
	//---------------------------------//
	i_ReqRN_dec	,
	i_Read_dec	,
	i_TestRead_dec,
	i_Write_dec	,
	i_TestWrite_dec	,
	i_inventory_dec	,
	i_Lock_dec	,
	i_payload_valid_cu	,
	i_wordcnt_rom	,
	i_datarate_ocu	,
	i_trext_dec	,
	i_m_dec		,
	i_clear_cu	,
	i_handle_cu		,
	i_random_cu		,
	i_data_crc	,
	//----------added by chengwu------------//
	i_key,
	i_ecc_outxa,
	i_ecc_outza,
	//--------------------------------------//
	o_data_ocu	,
	o_done_ocu	,
	o_back_rom_ocu	,
	o_crcen_ocu	,
	o_reload_ocu	,
	o_shift_crc	,
	o_enable_mod	,
	o_mblf_mod	,
	o_violate_mod	,
	o_shiftaddr_ocu
	
			);

input			clk		;
input			rst_n		;
input			i_ACK_dec	;
input			i_ReqRN_dec	;
input			i_Read_dec	;
input			i_Write_dec	;
input			i_TestWrite_dec	;
input			i_TestRead_dec;
input			i_inventory_dec	;
input			i_Lock_dec	;
input			i_payload_valid_cu	;
input	[15:0]		i_data_rom_16bits	;
input	[3:0]		i_wordcnt_rom	;
input			i_datarate_ocu	;
input			i_trext_dec	;
input	[1:0]		i_m_dec		;
input			i_clear_cu	;
input	[15:0]		i_handle_cu		;
input	[15:0]		i_random_cu		;
input	[15:0]		i_data_crc	;

output			o_data_ocu	;
reg			o_data_ocu	;
output			o_done_ocu	;
reg      o_done_ocu	;
output			o_back_rom_ocu	;
reg			o_back_rom_ocu	;
output			o_crcen_ocu	;
reg			o_crcen_ocu	;
output			o_reload_ocu	;
reg			o_reload_ocu	;
output			o_shift_crc	;
reg			o_shift_crc	;
output			o_enable_mod	;
reg			o_enable_mod	;
output			o_mblf_mod	;
reg			o_mblf_mod	;
output			o_violate_mod	;
reg			o_violate_mod	;

//-------------------added by lhzhu ---------------------//
input 		i_Authenticate_dec  ;
input[1:0] 		i_Authenticate_step_cu   ;
output		o_shiftaddr_ocu	;
reg		o_shiftaddr_ocu	;
//--------------------------------------------------------//

//-------------------added by chengwu ---------------------//
input[175:0] i_key,i_ecc_outxa,i_ecc_outza;
//--------------------------------------------------------//

parameter IDLE=5'd1, DONE=5'd0, 
	FourZ=5'd16, TwelveZ=5'd17, SixtromnZ=5'd18, 
	Header=5'd25, rom=5'd26, Handle=5'd27, DATA=5'd28, RN=5'd29, LockError=5'd19,
	Preamble=5'd24, CRC=5'd30, DUMMY=5'd31;
	
reg 	[4:0]		next, state	;
reg 	[3:0]		counter		;  
reg 	[4:0]		words		; 
reg 	[15:0]		data_source	; //���صĴ������
reg 				crc_exist	;	  //crc_exist����

always	@(posedge clk or negedge rst_n )
	if (~rst_n )
		state 	<=	IDLE 		;
	else if (i_clear_cu )
		state 	<=	IDLE 		;
	else
		state 	<=	next 		;
		
always @ (*)
begin
  next = state;
	case (state )
	IDLE :
		if (i_datarate_ocu )  //�뷵��������Ƶ����ȵ������źţ���֤״̬���Է�����������ת
			if (i_trext_dec ==1'b1 && i_m_dec ==2'b00) //�����Ƿ����ǰ����
				next 	=	TwelveZ  	;
			else if (i_trext_dec ==1'b1)
				next 	=	SixtromnZ 	;
			else if (i_m_dec ==2'b00)
				next 	=	Preamble 	;
			else 
				next 	=	FourZ 	;
		else
			next 	=	state 		;
	FourZ , TwelveZ , SixtromnZ :
		if (i_datarate_ocu && counter ==4'h0)
			next 	=	Preamble 	;
		else
			next 	=	state 		;
	Preamble :
		if (i_datarate_ocu && counter ==4'h0)
			case (1'b1)
			i_Lock_dec&&~i_payload_valid_cu:
				next	=	LockError	;
			i_Lock_dec&&i_payload_valid_cu:
				next	=	Header		;
			i_Read_dec , i_Write_dec , i_TestWrite_dec,i_TestRead_dec:
				next 	=	Header 		;
			i_ACK_dec :
				next 	=	rom 		;
			i_inventory_dec    :	
				next 	=	Handle 		;
			i_Authenticate_dec  :
				next 	=	DATA 		;
			i_ReqRN_dec   :
				next 	=	RN 		;
			default : next 	=	Handle 		;
			endcase
		else
			next 	=	state 		;
	Header :
		if (i_datarate_ocu && i_Read_dec||i_TestRead_dec )
			next 	=	rom 		;
		else if (i_datarate_ocu || i_Lock_dec&&i_payload_valid_cu)
			next 	=	Handle 		;
		else if (i_datarate_ocu )
			next 	=	Handle 		;
		else  
			next 	=	state 		;
	LockError:		//����ƺ�û��
		if(i_datarate_ocu && counter == 4'h0)
			next	=	Handle		;	
		else 	next	=	state		;	
	rom :
	    if (i_datarate_ocu && counter ==4'h0 && words ==4'h0)
			if (i_ACK_dec )
				next 	=	CRC 	;	  
			else
				next 	=	Handle 	;
		else
			next 	=	state 		;
	DATA :
     if (i_datarate_ocu && counter ==4'h0 && words ==4'h0) 
				next 	=	Handle 	;
		else
			next 	=	state 		;
	Handle :
		if (i_datarate_ocu && counter ==4'h0 )
			if (i_inventory_dec )
				next 	=	DUMMY  	;
			else 
				next 	=	CRC 	;
		else
			next 	=	state 		;
	RN :
		if (i_datarate_ocu && counter ==4'h0 )
			next 	=	CRC;//Handle 		;
		else 
			next 	=	state 		;
	CRC :
		if (i_datarate_ocu && counter ==4'h0 )
			next 	=	DUMMY  		;
		else 
			next 	=	state 		;
	DUMMY :
		if (i_datarate_ocu )
			next 	=	DONE 		;
		else 
			next 	=	state 		;
	DONE :		next 	=	IDLE 		;
	default :	next 	=	IDLE 		; 
	endcase 
	end
	
always @(posedge clk or negedge rst_n )
	if (~rst_n )
		counter 	<=	4'hf		;
	else if (state !=next )
		case (next )
		FourZ :		counter <=	4'h3	;
		TwelveZ :	counter <=	4'hb	;
		Preamble :	counter <=	4'h5	;
		LockError:	counter <=	4'h8	;
		Header ,DUMMY :	counter <=	4'h0 	;
		default :	counter <=	4'hf	;
		endcase 
	else if (i_datarate_ocu )
		counter 	<=	counter -4'h1	;

always @(posedge clk or negedge rst_n )
	if (~rst_n )
		words 		<=	5'h0 		;
	else if (state != next && next ==DATA && i_Authenticate_step_cu == 'd0 )
		words 		<=	5'h10 		;
	else if (state != next && next ==DATA && i_Authenticate_step_cu == 'd1 )
		words 		<=	5'h15 		;	
	else if (state != next && next ==rom )
		words 		<=	i_wordcnt_rom-1'b1 	;
	else if ( (state ==rom || state ==DATA ) && counter ==4'h0 && i_datarate_ocu )
		words 		<=	words-5'h1		;
		
always @ (*) 
	case (state )
	Preamble :
		if (i_m_dec ==2'b00)
			data_source 	=	16'h002b	;
		else 
			data_source 	=	16'h0017	;
	Header :
		data_source 	=	16'h0000	;
	rom :
		data_source 	=	i_data_rom_16bits 	;
	Handle :
		if (i_TestWrite_dec||i_TestRead_dec )
			data_source 	=	16'h789a	;
		else 
			data_source 	=	i_handle_cu 	;
	RN :
		data_source 	=	i_random_cu 	;
	LockError:
		data_source	=	16'h0104	;
	DATA :
		if(i_Authenticate_step_cu =='d0) // transfer cert
			case (words)
			5'ha:	data_source =	i_key [175:161]	;
			5'h9:	data_source =	i_key [159:144]	;
			5'h8:	data_source =	i_key [143:128]	;
			5'h7:	data_source =	i_key [127:112]	;
			5'h6:	data_source =	i_key [111:96]	;
			5'h5:	data_source =	i_key [95:80]	;
			5'h4:	data_source =	i_key [79:64]	;
			5'h3:	data_source =	i_key [63:48]	;
			5'h2:	data_source =	i_key [47:32]	;
			5'h1:	data_source =	i_key [31:16]	;
			5'h0:	data_source =	i_key [15:0]	;
			default :	data_source =	16'h0 		;
			endcase
		else if (i_Authenticate_step_cu=='d1)  //transfer xa za
			case (words )
			5'h15:	data_source =	i_ecc_outza [175:161]	;
			5'h14:	data_source =	i_ecc_outza [159:144]	;
			5'h13:	data_source =	i_ecc_outza [143:128]	;
			5'h12:	data_source =	i_ecc_outza [127:112]	;
			5'h11:	data_source =	i_ecc_outza [111:96]	;
			5'h10:	data_source =	i_ecc_outza [95:80]		;
			5'hf:	data_source =	i_ecc_outza [79:64]		;
			5'he:	data_source =	i_ecc_outza [63:48]		;
			5'hd:	data_source =	i_ecc_outza [47:32]		;
			5'hc:	data_source =	i_ecc_outza [31:16]		;
			5'hb:	data_source =	i_ecc_outza [15:0]		;
			
			5'ha:	data_source =	i_ecc_outxa [175:161]	;
			5'h9:	data_source =	i_ecc_outxa [159:144]	;
			5'h8:	data_source =	i_ecc_outxa [143:128]	;
			5'h7:	data_source =	i_ecc_outxa [127:112]	;
			5'h6:	data_source =	i_ecc_outxa [111:96]	;
			5'h5:	data_source =	i_ecc_outxa [95:80]		;
			5'h4:	data_source =	i_ecc_outxa [79:64]		;
			5'h3:	data_source =	i_ecc_outxa [63:48]		;
			5'h2:	data_source =	i_ecc_outxa [47:32]		;
			5'h1:	data_source =	i_ecc_outxa [31:16]		;
			5'h0:	data_source =	i_ecc_outxa [15:0]		;
			default :	data_source =	16'h0 				;
			endcase
		else data_source = 16'b0;
	CRC :
		data_source 	=	~i_data_crc ;
	DUMMY :
		data_source 	=	16'h0001	;
	FourZ ,SixtromnZ :
		data_source 	=	16'hffff	;
	default :
		data_source 	=	16'h0 		;
	endcase 

always @ (*)
 o_data_ocu 	=	data_source [counter ]   ;
always @ (*)
 crc_exist 		=	state ==Header ||state ==rom || state ==RN || state ==DATA || (state ==Handle && !i_inventory_dec )||state == LockError	;

always @ (*) 
	begin 
	o_enable_mod	=	(state == LockError)?1:state [4];
	o_done_ocu 		=	state ==DONE;
	o_mblf_mod	 	=	state ==FourZ || state ==SixtromnZ;
	o_violate_mod	=	state ==Preamble && i_m_dec ==2'b00 && counter =='h1 ;
	o_back_rom_ocu	=	(state ==Preamble) && counter =='h1 && (i_ACK_dec || i_Read_dec ||i_TestRead_dec) ;
	o_shiftaddr_ocu =  (state ==rom)&& (counter == 'h0) && (i_ACK_dec || i_Read_dec ||i_TestRead_dec) ;
	o_crcen_ocu		=	crc_exist && i_datarate_ocu 	;
	o_shift_crc		=	state ==CRC 	;
	o_reload_ocu	=	state ==Preamble &&counter =='h5 	;
	end

endmodule
 
 
 
