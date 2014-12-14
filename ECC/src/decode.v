`timescale 1ns/100ps
module	decode	(
	input	clk		,
	input	rst_n	,
	input	i_valid_dem	,
	input	i_data_dem	,
	input	i_newcmd_dem	,
	input	i_preamble_dem	,
	input	i_clear_cu	,
	//--------------added by lhzhu -------------//
	input	[1:0]	i_Authenticate_step_cu ,
	//--------------added by lhzhu -------------//
	output	reg 		o_Query_dec	,
	output	reg 		o_QueryRep_dec	,
	output	reg 		o_QueryAdjust_dec	,
	output	reg 		o_ACK_dec	,
	output	reg 		o_ReqRN_dec	,
	output	reg 		o_Read_dec	,
	output	reg 		o_Write_dec	,
	output	reg 		o_TestWrite_dec	,
	output	reg 		o_TestRead_dec,
	output	reg 		o_Lock_dec	,
	output	reg 		o_Select_dec	,
	output	reg 		o_inventory_dec	,
	output	reg 		o_data_dec	,
	output	reg 		o_cmdok_dec	,
	output	reg 		o_dr_dec		,
	output	reg [15:0]	o_handle_dec	,
	output	reg 		o_Lock_payload_dec	,
	output	reg [3:0]	o_q_dec		,
	output	reg [1:0]	o_m_dec		,
	output	reg 		o_length_shift_dec	,
	output	reg 		o_mask_shift_dec	,
	output	reg 		o_targetaction_shift_dec	,
	output	reg 		o_addr_shift_dec	,
	output	reg 		o_data_shift_dec	,
	output	reg 		o_wcnt_shift_dec	,
	output	reg 		o_trext_dec	,
	output	reg 		o_target_dec	,
	output	reg [1:0]	o_session_dec	,
	output	reg 		o_session_done	,
	output	reg [1:0]	o_session2_dec	,
	output	reg [1:0]	o_sel_dec	,
	output	reg 		o_Access_dec	,
	output	reg 		o_access_shift_dec	,
	output	reg 		o_ebv_flag_dec	,
//--------------added by lhzhu -------------//
	output	reg 		o_Authenticate_dec ,
	output	reg 		o_Authenticate_shift_dec	,			//authenticate��ѭ����λ�ź�
	output	reg 		o_Authenticate_ok_dec	,			//authenticate������������
	output	reg	[7:0]	o_csi_dec		,							//CSI����ֵ
	output	reg [7:0]	o_AuthParam_dec	,	
	output	reg [15:0]	o_Address_dec
	);

reg				o_NAK_dec	;
reg  [1:0]		o_rfu_dec ;
reg  			o_senRep_dec;
reg  			o_incRepLen_dec;
reg  [11:0]		message_length;

parameter	IDLE     	=	3'b000	; 
parameter	HUFFMAN 	=	3'b001	; 
parameter	DATA     	=	3'b010	; 
parameter	MESSAGE   	=	3'b011	; 
parameter	HANDLE   	=	3'b100	; 
parameter	CRC     	=	3'b101	; 
parameter	DONE     	=	3'b111	; 
	
reg	[2:0] 	state, next	;
reg	[10:0]	counter		;
reg	[7:0]	length		;
reg	[7:0]	huffbuf		;
reg			cmd_name_ok	;
reg	[10:0]	max_bits_data	;

always	@(posedge clk or negedge rst_n)
	if (~rst_n)
		state	<=	IDLE		;
	else state	<=	next		;
	
always @ (*)
	begin
			next	=	state	;
	case	(state	)
	IDLE:	
		if (i_newcmd_dem)
			next	=	HUFFMAN	;
		else
			next	=	state	;
	HUFFMAN:
		if (cmd_name_ok && o_NAK_dec) //NAKָ�ʹ�ص�arbitrate״̬������һ��ʼ��ready״̬��
			next	=	DONE	;
		else if (cmd_name_ok && (o_ACK_dec||o_ReqRN_dec))//�⼸������ֱ�ӵ�HANDLE��
			next	=	HANDLE	;
		else if (cmd_name_ok)		  
			next	=	DATA	;
		else
			next	=	state	;
	DATA:
		if (counter==max_bits_data && o_Query_dec) //DATA�ε������λ��
			next	=	CRC	;
		else if(counter>=max_bits_data && o_Select_dec && length == 8'h00) //selectָ��ֱ������handle
			next	=	CRC	;
		else if (counter==max_bits_data && (o_QueryAdjust_dec||o_QueryRep_dec) )//queryadjust ��queryrep ָ������CRC��handle
			next	=	DONE	;
		else if (counter==(max_bits_data-'d8)&& (o_Write_dec ||o_Read_dec ||o_TestRead_dec ||o_TestWrite_dec ) && ~o_ebv_flag_dec ) //δ��ebv���뷽ʽ�Σ���read/write��ָ��max_bit_data-8
			next	=	HANDLE	;
		else if (o_Authenticate_dec && counter==max_bits_data )
			next 	= 	MESSAGE;
		else if (~o_Select_dec && counter==max_bits_data)//���������
			next	=	HANDLE	;
		else 
			next	=	state	;
	MESSAGE:
		if(counter == message_length)
			next	=	HANDLE	;
	HANDLE:
		if (counter=='d16 && o_ACK_dec) //ACKָ��û��CRC16��
			next	=	DONE	;
		else if (counter=='d16) //handle�ε�16�������ת��CRC��ȥ�ˣ�clk�Ǻܿ�ģ�
			next	=	CRC	;
		else
			next	=	state	;
	CRC:
		if (counter==max_bits_data )
			next	=	DONE	;
		else 
			next	=	state 	;
	DONE :		next 	=	IDLE 	;
	default:	next	=	IDLE	;
	endcase
	end	

always	@(posedge clk or negedge rst_n)
	if (~rst_n)
		huffbuf		<=	8'h0	;
	else if (i_newcmd_dem)
		huffbuf		<=	8'h0	;
	else if (state==HUFFMAN && i_valid_dem)//�μ����ģ�飺PIE�����Ч�ź�
		huffbuf		<=	{huffbuf[6:0],i_data_dem}	; //i_valid_dem��ʱ��huffbufѭ������
		
always	@(posedge clk or negedge rst_n) //��counter����,counter�����Ѿ�decode����λ��
	if (~rst_n)
		counter		<=	'h0	;
	else if (o_Select_dec && (counter >= 'd24) && length> 8'h01 ) //��selectָ��ĵ�25λ��ʼ��������mask�Σ���������counter�ˣ���counter����24��ֵ������ȡmask
		counter		<=	counter	; 								//Ϊʲôlength��>8'h01?
	else if (i_valid_dem)
		counter		<=	counter + 'h1	;   //ֻҪ��i_valid_dem����һ�Σ�����1��CLK�����´�clk��counter+1
	else if (state!=next)
		counter		<=	'h0	; 				//��״̬�� ��0��ʼ����

always	@(posedge clk or negedge rst_n)//ֻ��Selectָ������� Select�еĲ���Length��Ϊ��IventoryĳЩtag population����
	if(~rst_n)
		length		<=	8'h00	;
	else if (o_Select_dec||o_Select_dec && counter >= 'd16 && counter <= 'd23 && i_valid_dem)  //EBV��8bit���ȣ���3+3+2+8=16Ϊlength֮ǰ�ĳ��ȣ�lengthΪ��17-24λ	��counter=8��d16�����Ѿ�ȡ����16λ���ڵȴ�ȡ��17λ
		length		<=	{length[6:0],i_data_dem}	;											//��counter=23Ϊȡ��24λ��counter=24�Ѿ���Maskλ�ˡ�
	else if (o_Select_dec && (counter >= 'd24) && i_valid_dem && length != 'h0) //��ߵĲ�������Mask�����ˣ����Ҫ���ϼ�1
		length		<=	length - 8'h1	;
	else if (state != next)
		length		<=	8'h00;
		
always	@(posedge clk or negedge rst_n)
	if (~rst_n )
		begin
		o_QueryRep_dec		<=	1'b0	;
		o_ACK_dec			<=	1'b0	;
		o_Query_dec			<=	1'b0	;
		o_QueryAdjust_dec	<=	1'b0	;
		o_NAK_dec			<=	1'b0	;
		o_ReqRN_dec			<=	1'b0	;
		o_Read_dec			<=	1'b0	;
		o_Write_dec			<=	1'b0	;
		o_TestWrite_dec		<=	1'b0	;
		o_Lock_dec			<=	1'b0	;
		o_Select_dec		<=	1'b0	;
		o_Access_dec		<=	1'b0	;
		o_TestRead_dec		<=	1'b0	;
		o_Authenticate_dec <= 1'd0  ;//by lhzhu
		end
	else if (i_newcmd_dem || i_clear_cu)
		begin
		o_QueryRep_dec		<=	1'b0	;
		o_ACK_dec			<=	1'b0	;
		o_Query_dec			<=	1'b0	;
		o_QueryAdjust_dec	<=	1'b0	;
		o_NAK_dec			<=	1'b0	;
		o_ReqRN_dec			<=	1'b0	;
		o_Read_dec			<=	1'b0	;
		o_Write_dec			<=	1'b0	;
		o_TestWrite_dec		<=	1'b0	;
		o_Lock_dec			<=	1'b0	;
		o_Select_dec		<=	1'b0	;
		o_Access_dec		<=	1'b0	;
		o_TestRead_dec		<=	1'b0	;
		o_Authenticate_dec <= 1'd0  ;//by lhzhu
		end
	else if (state==HUFFMAN) begin 
		if (counter=='h2)
			case(huffbuf[1:0])
			2'b00:		o_QueryRep_dec		<=	1'b1	;
			2'b01:		o_ACK_dec			<=	1'b1	;
			default:	;
			endcase
		else if (counter=='h4)
			case(huffbuf[3:0])
			4'b1000:	
				if (i_preamble_dem)
					o_Query_dec			<=	1'b1	;
			4'b1001:	o_QueryAdjust_dec		<=	1'b1	;	
			4'b1010:	o_Select_dec		<=	1'b1	;
			default:	;
			endcase
		else if (counter=='h8) //����ʲô״̬���������롣controlģ���������
			case(huffbuf)
			8'hc0:		o_NAK_dec			<=	1'b1	;	
			8'hc1:		o_ReqRN_dec			<=	1'b1	;	
			8'hc2:		o_Read_dec			<=	1'b1	;	
			8'hc3:		o_Write_dec			<=	1'b1	;
			8'hc5:		o_Lock_dec			<=	1'b1	;	
			8'hc6:		o_Access_dec		<=	1'b1	;
			8'hc8:		o_TestWrite_dec		<=	1'b1	;	
			8'hda:		o_TestRead_dec		<=	1'b1	;
			8'hd5:		o_Authenticate_dec  <=  1'b1    ; 
			default:	;
			endcase
			else;
		end
		else;
		
always @ (*)
	cmd_name_ok	=	o_QueryRep_dec	|| o_ACK_dec	|| o_Query_dec	|| o_QueryAdjust_dec
				|| o_NAK_dec	|| o_ReqRN_dec	|| o_Read_dec	|| o_Write_dec	
				|| o_TestWrite_dec || o_Lock_dec || o_Select_dec|| o_Access_dec
				||o_TestRead_dec||o_Authenticate_dec;

always @ (*)
	o_inventory_dec	=	o_Query_dec || o_QueryAdjust_dec || o_QueryRep_dec	;

always	@(posedge clk or negedge rst_n)
	if (~rst_n)
		o_cmdok_dec		<=	1'b0	; //command ok 
	else if (i_newcmd_dem || i_clear_cu)  //�յ��µ�command�����ڲ���λ�ź�
		o_cmdok_dec		<=	1'b0	;
	else if (state==DONE)
		o_cmdok_dec		<=	1'b1	; //�����������,����state=done��ʱ����һ��clk�ĸߵ�ƽ
	else
		o_cmdok_dec		<=	1'b0	;
		
always @ (*)
	if (state==DATA)
		case	(1'b1)
		o_QueryRep_dec:	
			max_bits_data	=	'd2	;
		o_Query_dec:
			max_bits_data	=	'd13	;
		o_QueryAdjust_dec:
			max_bits_data	=	'd5	;
		o_Read_dec,o_TestRead_dec:
			max_bits_data	=	'd26	;
		o_Write_dec, o_TestWrite_dec:
			max_bits_data	=	'd34	;
		o_Lock_dec	:			
			max_bits_data	=	'd20	;
		o_Select_dec :
			max_bits_data	=	'd25	;
		o_Access_dec :	
			max_bits_data	=	'd16	;
		o_Authenticate_dec:
			max_bits_data  =   'd24;
		default :
			max_bits_data 	=	'd0	;
		endcase
	else if (state ==CRC && o_Query_dec )
		max_bits_data 		=	'd5 	;
	else if (state ==CRC )
		max_bits_data 		=	'd16	;
	else
		max_bits_data	=	'd0	;
	
	
always @ (*)
	o_session_done	=	counter=='d8&&i_valid_dem&&o_Query_dec&&state==DATA; //query��data counter����8 ���ɲ�ѯ�����õ�sessionλ������

always	@(posedge clk or negedge rst_n)
	if (~rst_n)
		begin
		o_q_dec	<=	4'h0		;
		o_dr_dec	<=	1'b0	;
		o_m_dec	<=	2'h0		;
		o_trext_dec	<=	1'b0	;
		o_sel_dec	<=	2'b0	;
		o_session_dec<=	2'b0	;
		o_target_dec<=	1'b0	;
		o_session2_dec<=2'b0	;
		o_csi_dec	<=	8'b0 	;
		o_Address_dec <= 16'd0	;
		o_AuthParam_dec <= 8'hff	;
		end
	else if (o_Query_dec && state==DATA && i_valid_dem)
		begin
		if (counter=='d0)
			o_dr_dec	<=	i_data_dem		;
		else if (counter=='d1 || counter=='d2)
			o_m_dec	<=	{o_m_dec[0],i_data_dem}	;
		else if (counter=='d3)
			o_trext_dec	<=	i_data_dem		;
		else if (counter == 'd4 || counter == 'd5)
			o_sel_dec	<=	{o_sel_dec[0],i_data_dem}		;
		else if (counter == 'd6 || counter == 'd7 )
			begin	
			o_session_dec	<=	{o_session_dec[0],i_data_dem}	; // ��query��data 6/7 λȡ����Ϊ o_session_dec��������session��λ��
			end
		else if	(counter == 'd8)
			o_target_dec<=	i_data_dem		;
		else if (counter[3:0]>='d9)
			o_q_dec	<=	{o_q_dec[2:0],i_data_dem};
		end
	else if (o_QueryAdjust_dec  && state==DATA && i_valid_dem)
		begin 
		if (counter =='d2 && i_data_dem )
			o_q_dec 	<=	o_q_dec +1 		;
		else if (counter == 'd0 || counter == 'd1)
			o_session2_dec<=	{o_session2_dec[0],i_data_dem}; // ��query adjust��data 0/1 λȡ����Ϊ o_session_dec��������session��λ��
		else if (counter =='d4 && i_data_dem )
			o_q_dec 	<=	o_q_dec -1 		;
		end
	else if(o_QueryRep_dec && state == DATA&& (counter == 'd0 || counter == 'd1)&& i_valid_dem)
		o_session2_dec	<=	{o_session2_dec[0],i_data_dem};     // ��query rep��data 0/1 λȡ����Ϊ o_session_dec��������session��λ��
	else if(o_Authenticate_dec && state == MESSAGE && (counter <= 'd7)&& i_valid_dem)
		o_AuthParam_dec <= {o_AuthParam_dec[6:0],i_data_dem};
	else if(o_Authenticate_dec && state == MESSAGE && (counter <= 'd23) && o_AuthParam_dec == 'h01 && i_valid_dem)
		 o_Address_dec	<= {o_Address_dec[14:0],i_data_dem};	
	else;

//--------------------------added by chengwu----------------------------	
always@(posedge clk or negedge rst_n)
if(~rst_n)
begin
		o_rfu_dec <='d0;
		o_senRep_dec<='d0;
		o_incRepLen_dec<='d0;
		o_csi_dec='d0;
		message_length<='d0;
end
else	if(o_Authenticate_dec && state == DATA && i_valid_dem)
        begin
			if(counter=='d0 || counter=='d1)
				o_rfu_dec <= {o_rfu_dec[0],i_data_dem};
			else if(counter=='d2)
				o_senRep_dec <= i_data_dem;
			else if(counter=='d3)
				o_incRepLen_dec  <= i_data_dem;
			else if(counter[4:0]>'d3 && counter[4:0]<'d12)
				o_csi_dec <= {o_csi_dec[6:0],i_data_dem};
			else if(counter[4:0]<'d24)
				message_length <= {message_length[10:0],i_data_dem};
		end
else;
			
//-----------------------------------------------------------------------		
				
always @(posedge clk or negedge rst_n)
	if(~rst_n)
		o_ebv_flag_dec	<=	1'b0	;
	else if((o_Write_dec ||o_Read_dec ||o_TestRead_dec ||o_TestWrite_dec ) && state ==DATA &&counter=='d2&& i_data_dem) //ֻ�е�=1��ʱ����λ��չΪ1ʱ������EBV����
		o_ebv_flag_dec	<=	1'b1	; //counter��2��ʱ��,�Ѿ���ȡ��bank��Ϣ��׼��������λ����ʱo_ebv_flag_dec=1'b1����ʾ�ѽ���EBV��ʽ
	 else if(i_newcmd_dem)//~(o_Write_dec ||o_Read_dec ||o_TestRead_dec ||o_TestWrite_dec ) )
		o_ebv_flag_dec	<=	1'b0	;

always @ (*)
	if(o_Access_dec && state == DATA)
		o_access_shift_dec	=	i_valid_dem		;
	else 
		o_access_shift_dec	=	1'b0			;

always @ (*)
	if(o_Lock_dec && state ==  DATA && counter <'d20 )
		o_Lock_payload_dec	=	i_valid_dem		;
	else
		o_Lock_payload_dec	=	1'b0			;
always @ (*)
	if (o_Select_dec && state == DATA && counter > 'd15 && counter < 'd24 ) //
		o_length_shift_dec	=	i_valid_dem		;
	else 
		o_length_shift_dec	=	1'b0			;

always @ (*) 
	if(o_Select_dec && state == DATA && counter == 'd24 && length >0) //selectָ���mask shift�ź�
		o_mask_shift_dec 	=	i_valid_dem			;
	else	
		o_mask_shift_dec	=	1'b0			;
always @ (*)
	if (o_Select_dec && state == DATA && counter < 'd6) //
		o_targetaction_shift_dec	=	i_valid_dem		;
	else	
		o_targetaction_shift_dec	=	1'b0		;

always @ (*) 
	if (o_ebv_flag_dec && (o_Write_dec ||o_Read_dec ||o_TestRead_dec ||o_TestWrite_dec ) && state ==DATA &&((counter <'d2)|| (counter >'d2&&counter< 'd18)&&(counter != 'd10 )))//��������3λ�Լ���11λ������λ����EBV����չλ,����֮
		o_addr_shift_dec	=	i_valid_dem 	;
	else if (~o_ebv_flag_dec&&(o_Write_dec ||o_Read_dec ||o_TestRead_dec ||o_TestWrite_dec ) && state ==DATA &&((counter <'d2) || (counter >'d2&&counter< 'd10) ))//��������3λ,û�еڶ��ε���չλ
		o_addr_shift_dec	=	i_valid_dem 	;
	else if(o_Select_dec && state == DATA && counter >'d5 && counter <'d12)
		o_addr_shift_dec	=	i_valid_dem 	;
	else 
		o_addr_shift_dec 	=	1'b0 			;

always @ (*) 
	if (o_ebv_flag_dec&&(o_Read_dec ||o_TestRead_dec) &&state ==DATA && (counter >'d17 && counter <'d26)) //Wordcount for read
		o_wcnt_shift_dec	=	i_valid_dem 	;
	else if (~o_ebv_flag_dec&&(o_Read_dec ||o_TestRead_dec) &&state ==DATA && (counter >'d9 && counter <'d18))
		o_wcnt_shift_dec	=	i_valid_dem 	;
	else 
		o_wcnt_shift_dec 	=	1'b0 			;
		
always @ (*) 
	if (o_ebv_flag_dec&&( (o_Write_dec ||o_TestWrite_dec ) &&state ==DATA && (counter >'d17 && counter <'d34)))
		o_data_shift_dec	=	i_valid_dem 	;
	else if (~o_ebv_flag_dec&&((o_Write_dec ||o_TestWrite_dec ) &&state ==DATA && (counter >'d9 && counter <'d26)))
		o_data_shift_dec	=	i_valid_dem 	;
	else 
		o_data_shift_dec  	=	1'b0 			;			
	
	
always @ (*)
	if (i_valid_dem )
		o_data_dec		=	i_data_dem 	;
	else
		o_data_dec 		=	1'b0			;

always 	@(posedge clk or negedge rst_n ) //handle����λ����
	if (~rst_n )
		o_handle_dec	<=	16'h0 			;
	else if (state ==HANDLE && i_valid_dem )
		o_handle_dec 	<=	{o_handle_dec [14:0], i_data_dem }	;
		
 
 //-------------for authentication control, by lhzhu-------------
always @ (*)
	if (state ==MESSAGE && o_Authenticate_dec && counter >= 'd8)
		begin 
		o_Authenticate_shift_dec <= i_valid_dem;  // authenticate �½����������Ч�ź�
		o_Authenticate_ok_dec    <= counter == message_length ;
		end
	else begin
		o_Authenticate_shift_dec 	<=	1'b0 	;
		o_Authenticate_ok_dec 		<=	1'b0 	;
	end

endmodule 
