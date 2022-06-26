`timescale 1ns / 1ps

module i2c_temp(
input  clk,		
input  rst_n,	//reset sinyali
input  sw1,	//Okuma işlemini yapılıp yapılmaması
output scl,	//i2c clock (saat) çıkışı	
inout  sda,	//i2c data port	
output [15:0] dis_data	//Belirtilen hücrenin output dataları
);

//ADT7420 Tempurature Sensor Kullanılmıştır.


//Switch (anahtar) algılama
reg sw2_r;	
reg[19:0] cnt_20ms;	 // Her 20ms de bir sw registerın değerini kontrol eder

always @ (posedge clk or negedge rst_n)
	if(rst_n) 
	   cnt_20ms <= 20'd0;
	else 
	   cnt_20ms <= cnt_20ms+1'b1;	

always @ (posedge clk or negedge rst_n)
	if(rst_n) 
		begin
			sw2_r <= 1'b1;  //reset sinyali geldiğinde registerın değeri 1 olur
		end
	else if(cnt_20ms == 20'hfffff) 
		begin
			sw2_r <= sw1;	
		end


reg[2:0] cnt;	//cnt = 0: scl yükselen kenar(rising edge), cnt = 1: scl High seviyesinin ortası, cnt = 2: scl düşen kenar(falling edge), cnt = 3: scl Low seviyesinin ortası
reg[8:0] cnt_delay;	//FPGA saatin 500
reg scl_r;		//her saat darbesinin kaydı

always @ (posedge clk or negedge rst_n)
	if(rst_n) 
	   cnt_delay <= 10'd0;
	else if(cnt_delay == 10'd999) 
	   cnt_delay <= 10'd0;	//Scl'in periyodu 100KHz olduğu için 10us kadar sayar
	else 
	   cnt_delay <= cnt_delay+1'b1;	

always @ (posedge clk or negedge rst_n) begin
	if(rst_n) 
	   cnt <= 3'd5;
	else 
	  begin
		 case (cnt_delay)
			9'd124:	cnt <= 3'd1;  //cnt = 1: scl High seviyesinin ortası, data örneklemesi için kullanılır	
			9'd249:	cnt <= 3'd2;  //cnt = 2: scl düşen kenear (falling edge)	
			9'd374:	cnt <= 3'd3;  //cnt = 3: scl low seviye orta, data değişiklikleri için kullanılır	
			9'd499:	cnt <= 3'd0;  //cnt = 0: scl yükselen kenar (rising edge)	
			default: cnt <= 3'd5;
		  endcase
	  end
end

`define SCL_POS		(cnt==3'd0)	//cnt = 0: scl yükselen kenar (rising edge)	
`define SCL_HIG		(cnt==3'd1)	//cnt = 1: scl High seviyesinin ortası, data örneklemesi için kullanılır	
`define SCL_NEG		(cnt==3'd2)	//cnt = 2: scl düşen kenear (falling edge)	
`define SCL_LOW		(cnt==3'd3)	//cnt = 3: scl low seviye orta, data değişiklikleri için kullanılır	

always @ (posedge clk or negedge rst_n)
	if(rst_n) 
	    scl_r <= 1'b0;
	else if(cnt==3'd0) 
	    scl_r <= 1'b1;	//scl sinyali yükselen kenar
   	else if(cnt==3'd2) 
        scl_r <= 1'b0;		//scl sinyali düşen kenar

assign scl = scl_r;	



//Adres ve dataların ataması
`define	DEVICE_READ	8'b10010111  //Okuma İşlemi Adresi	
`define DEVICE_WRITE	8'b10010110  //Yazma işlemi Adresi	

`define	WRITE_DATA      8'b00000111	
`define BYTE_ADDR       8'b00000000		

reg[7:0] db_r;		
reg[15:0] read_data;	




parameter 	IDLE 	= 4'd0;
parameter 	START1 	= 4'd1;
parameter 	ADD1 	= 4'd2;//Cihazın adresi
parameter 	ACK1 	= 4'd3;//Acknowlege Sinyali
parameter 	ADD2 	= 4'd4;
parameter 	ACK2 	= 4'd5;
parameter 	START2 	= 4'd6;
parameter 	ADD3 	= 4'd7;
parameter 	ACK3	= 4'd8;
parameter 	DATA1 	= 4'd9;//Sıcaklığın ilk 8 biti
parameter 	ACK4	= 4'd10;
parameter 	DATA2 	= 4'd11;//Sıcaklığın ikinci 8 biti
parameter 	NACK	= 4'd12;
parameter 	STOP1 	= 4'd13;
parameter 	STOP2 	= 4'd14;
	
reg[3:0] cstate; //Case Statement kaydı	
reg sda_r;	 //Output Data Kaydı
reg sda_link;	 //Output ya da input sinyali için kontrol biti	
reg[3:0] num;	 //Bayt okurken kullanılan sayaç
always @ (posedge clk or negedge rst_n) begin
	if(rst_n) 
		begin
			cstate <= IDLE;
			sda_r <= 1'b1;
			sda_link <= 1'b0;
			num <= 4'd0;
			read_data <= 16'b0000_0000_0000_0000;
		end
	else 	  
		case (cstate)
			IDLE:	
				begin
					sda_link <= 1'b1; //sda input durumunda			
					sda_r <= 1'b1;
					if(!sw2_r) 
						begin			
						  db_r <= `DEVICE_WRITE; // Cihaz adresini gönderir (Yazma İşlemi)	
						  cstate <= START1;		
						end
					else 
					   cstate <= IDLE;	
				end
			START1: 
				begin
					if(`SCL_HIG) 
					    begin	//scl high konuma geçtiğinde	
						  sda_link <= 1'b1;	//sda output durumundadır
						  sda_r <= 1'b0;		
						  cstate <= ADD1;
						  num <= 4'd0;	//sayaç sıfırlandı	
						end
					else 
					    cstate <= START1; //Scl'in High seviyesinin ortasına gelmesini bekliyor
				end
			ADD1:	
				begin
					if(`SCL_LOW) 
						begin
							if(num == 4'd8) 
								begin	
									num <= 4'd0;			
									sda_r <= 1'b1;
									sda_link <= 1'b0; //Sda Yüksek Empedans durumuna geçti 		
									cstate <= ACK1;
								end
							else 
								begin
									cstate <= ADD1;
									num <= num+1'b1;
									case (num)
										4'd0: sda_r <= db_r[7];
										4'd1: sda_r <= db_r[6];
										4'd2: sda_r <= db_r[5];
										4'd3: sda_r <= db_r[4];
										4'd4: sda_r <= db_r[3];
										4'd5: sda_r <= db_r[2];
										4'd6: sda_r <= db_r[1];
										4'd7: sda_r <= db_r[0];
										default: ;
									endcase
								end
						end
					else 
					   cstate <= ADD1;
				end
			ACK1:	
				begin
					if(/*!sda*/`SCL_NEG) 
						begin	
							cstate <= ADD2;	 //Slave yanıt sinyali
							db_r <= `BYTE_ADDR;			
						end
					else 
					   cstate <= ACK1;	//Slave'den yanıt bekleniyor	
				end
			ADD2:	
				begin
					if(`SCL_LOW) 
						begin
							if(num==4'd8) 
								begin	
									num <= 4'd0;			
									sda_r <= 1'b1;
									sda_link <= 1'b0;	//Sda Yüksek Empedans durumuna geçti 	
									cstate <= ACK2;
								end
							else 
								begin
									sda_link <= 1'b1;	//sda output durumunda	
									num <= num+1'b1;
									case (num)
										4'd0: sda_r <= db_r[7];
										4'd1: sda_r <= db_r[6];
										4'd2: sda_r <= db_r[5];
										4'd3: sda_r <= db_r[4];
										4'd4: sda_r <= db_r[3];
										4'd5: sda_r <= db_r[2];
										4'd6: sda_r <= db_r[1];
										4'd7: sda_r <= db_r[0];
										default: ;
									endcase	
									cstate <= ADD2;					
								end
						end
					else 
					    cstate <= ADD2;				
				end
			ACK2:	begin
					if(/*!sda*/`SCL_NEG) begin	//Slave yanıt siynali	
						if(!sw2_r) begin
								db_r <= `DEVICE_READ; //Cihaz adresinin okuma işlemi için gönderildiği state 	
								cstate <= START2;		
							end
						end
					else cstate <= ACK2;	//Slave'den yanıt bekleniyor
				end
			START2: begin	//Start Biti OKuma
					if(`SCL_LOW) begin
						sda_link <= 1'b1;	//sda output durumunda
						sda_r <= 1'b1;		
						cstate <= START2;
						end
					else if(`SCL_HIG) begin	//scl high seviyesinin ortası

						sda_r <= 1'b0;		
						cstate <= ADD3;
						end	 
					else cstate <= START2;
				end
			ADD3:	begin	
					if(`SCL_LOW) begin
							if(num==4'd8) begin	
									num <= 4'd0;			
									sda_r <= 1'b1;
									sda_link <= 1'b0; //Sda Yüksek Empedans durumuna geçti		
									cstate <= ACK3;
								end
							else begin
									num <= num+1'b1;
									case (num)
										4'd0: sda_r <= db_r[7];
										4'd1: sda_r <= db_r[6];
										4'd2: sda_r <= db_r[5];
										4'd3: sda_r <= db_r[4];
										4'd4: sda_r <= db_r[3];
										4'd5: sda_r <= db_r[2];
										4'd6: sda_r <= db_r[1];
										4'd7: sda_r <= db_r[0];
										default: ;
										endcase
									cstate <= ADD3;					
								end
						end
					else cstate <= ADD3;				
				end
			ACK3:	begin
					if(/*!sda*/`SCL_NEG) begin
							cstate <= DATA1;  //Slave yanıt sinyali
							sda_link <= 1'b0;
						end
					else cstate <= ACK3; 		   //Slave'den yanıt bekleniyor
				end
			DATA1:	begin
					if(!sw2_r) begin	 
							if(num<=4'd7) begin
								cstate <= DATA1;
								if(`SCL_HIG) begin	
									num <= num+1'b1;	
									case (num)
										4'd0: read_data[15] <= sda;
										4'd1: read_data[14] <= sda;  
										4'd2: read_data[13] <= sda; 
										4'd3: read_data[12] <= sda; 
										4'd4: read_data[11] <= sda; 
										4'd5: read_data[10] <= sda; 
										4'd6: read_data[9] <= sda; 
										4'd7: read_data[8] <= sda; 
										default: ;
										endcase
									end
								end
							else if((`SCL_LOW) && (num==4'd8)) begin
								num <= 4'd0;			
								cstate <= ACK4;
								end
							else cstate <= DATA1;
						end
				end
			ACK4: begin		//Scl high olduğunda, sda de low olduğunda, Master tarafından gönderilen ack'i temsil eder
					if(/*!sda*/`SCL_HIG)
					 begin
					sda_link <= 1'b1;
						sda_r <= 1'b0;
						cstate <= DATA2;						
						end
					else cstate <= ACK4;
				end
		DATA2:	begin
                        if(!sw2_r) begin     
                                if(num<=4'd7) begin
                                    cstate <= DATA2;
                                    if(`SCL_HIG) begin    
                                        num <= num+1'b1;    
                                        case (num)
                                            4'd0: read_data[7] <= sda;
                                            4'd1: read_data[6] <= sda;  
                                            4'd2: read_data[5] <= sda; 
                                            4'd3: read_data[4] <= sda; 
                                            4'd4: read_data[3] <= sda; 
                                            4'd5: read_data[2] <= sda; 
                                            4'd6: read_data[1] <= sda; 
                                            4'd7: read_data[0] <= sda; 
                                            default: ;
                                            endcase
                                        end
                                    end
                                else if((`SCL_LOW) && (num==4'd8)) begin
                                    num <= 4'd0;            
                                    cstate <= NACK;
                                    end
                                else cstate <= DATA2;
                            end
                    end
                NACK: begin
                        if(/*!sda*/`SCL_HIG) begin	//Scl high olduğunda, sda de high olduğunda, nack anlamına gelir
                        sda_link <= 1'b1;
                           sda_r <= 1'b1;
                            cstate <= STOP1;                        
                            end
                        else cstate <= NACK;
                    end
			STOP1:	begin
					if(`SCL_LOW) begin
							sda_link <= 1'b1;
							sda_r <= 1'b0;
							cstate <= STOP1;
						end
					else if(`SCL_HIG) begin
							sda_r <= 1'b1;	//scl high durumuna geçtiğinde sda Yükselen Kenar Sinyali üretir (Bitiş sinyali)
							cstate <= STOP2;
						end
					else cstate <= STOP1;
				end
			STOP2:	begin
					if(`SCL_LOW) sda_r <= 1'b1;
					else if(cnt_20ms==20'hffff0) cstate <= IDLE;
					else cstate <= STOP2;
				end
			default: cstate <= IDLE;
			endcase
end

assign sda = sda_link ? sda_r:1'bz;
assign dis_data = read_data;

endmodule