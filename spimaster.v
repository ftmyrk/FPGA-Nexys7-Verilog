//    Spi_master, tüm arayüzün durumunu kontrol eder. 
//    Baþka modüllerle etkileþim kurabilmek için bir takým sinyaller kullanmak gerekir.
//    Spi_master, iletilecek verileri seçer ve PmodACL'den alýnan tüm verileri saklar.

module SPImaster(
   input            rst,            //Reset sinyali
   input            clk,            //FPGA clock 100Mhz
   input            start,
   input            done,           //Tamamlanmýþ iletim sonucu gönderilen sinyal  
   input [7:0]      rxdata,         //Recieve Data
   output reg      transmit,        //iletimin baþlangýcý için gönderilen sinyal
   output reg [15:0]    txdata,     
   output reg [7:0]   y_axis_data   
);

   // Define FSM states
   parameter [2:0]  IDLE = 3'd0,
                    CONFIGURE = 3'd1,
                    TRANSMIT = 3'd2,
                    RECEIVE = 3'd3,
                    FINISH = 3'd4,
                    BREAK = 3'd5,
                    HOLD = 3'd6;

   reg [2:0]        STATE;
   
   parameter [1:0]  data_type_y_axis = 2'd1;

   
   parameter [1:0]  powerCtl = 0,
                    bwRate = 1,
                    dataFORMAT = 2;
   reg [1:0]        CONFIGUREsel;
   
   //Configurasyon Register Yapýlandýrma
   //POWER_CTL Bits 0x2D
   parameter [15:0] POWER_CTL = 16'h2D08;
   //BW_RATE Bits 0x2C
   parameter [15:0] BW_RATE = 16'h2C08;
   //CONFIG Bits 0x31
   parameter [15:0] DATA_FORMAT = 16'h3100;
   
   //Eksen (Axis) Registerlarý, tek baytlýk artýþlarla sadece okuma yapma üzerine ayarlandý
   parameter [15:0] yAxis0 = 16'hB400;		//10110100;
   parameter [15:0] yAxis1 = 16'hB500;		//10110101;
   
   reg [11:0]       break_count;
   reg [20:0]       hold_count;
   reg              end_configure;
   reg              done_configure;
   reg              register_select;
   reg              finish;
   reg              sample_done;
   reg [3:0]        prevstart;
   


		always @(posedge clk)
		begin: spi_masterProcess
			begin
				// Geri Döndürme Baþlat Butonu
				prevstart <= {prevstart[2:0], start};
				//Reset Þartlarý
				if (rst == 1'b1) begin
					transmit <= 1'b0;
					STATE <= IDLE;
					break_count <= 12'h000;
					hold_count <= 21'b000000000000000000000;
					done_configure <= 1'b0;
					CONFIGUREsel <= powerCtl;
					txdata <= 16'h0000;
					register_select <= 1'b0;
					sample_done <= 1'b0;
					finish <= 1'b0;
					y_axis_data <= 8'b0000000000;
					end_configure <= 1'b0;
				end
				else
					//Main State, genel sistemin ne yapacaðýný seçer
					case (STATE)
						IDLE :
							//Sistem Configure edilmemiþse configure state'e girer
							if (done_configure == 1'b0) begin
								STATE <= CONFIGURE;
								txdata <= POWER_CTL;
								transmit <= 1'b1;
							end
							//Eðer configure edilmiþse, start sinyali geldiðinde transmission state'e geçer
							else if (prevstart == 4'b0011 & start == 1'b1 & done_configure == 1'b1) begin
								STATE <= TRANSMIT;
								finish <= 1'b0;
								txdata <= yAxis0;
								sample_done <= 1'b0;
							end
						CONFIGURE :
							case (CONFIGUREsel)
								//Güç kontrol adresini istenen konfigürasyon biti gönderilir
								powerCtl : begin
										STATE <= FINISH;
										CONFIGUREsel <= bwRate;
										transmit <= 1'b1;
									end
								//Band geniþliði adresini istenen Konfigürasyon biti gönderilir
								bwRate : begin
										txdata <= BW_RATE;
										STATE <= FINISH;
										CONFIGUREsel <= dataFORMAT;
										transmit <= 1'b1;
									end
								//data format adresini istenen konfigürasyon biti gönderilir
								dataFORMAT : begin
										txdata <= DATA_FORMAT;
										STATE <= FINISH;
										transmit <= 1'b1;
										finish <= 1'b1;
										end_configure <= 1'b1;
									end
								default :
									;
							endcase
						
						TRANSMIT :
								begin
									STATE <= RECEIVE;
									transmit <= 1'b1;
								end
											
						//Receive, verilerin spi_master'a akýþýný kontrol eder
						RECEIVE :
									case (register_select)
										1'b0 :
											begin
												transmit <= 1'b0;
												if (done == 1'b1)
												begin
													txdata <= yAxis1;
													y_axis_data[7:0] <= rxdata[7:0];
													register_select <= 1'b1;
													STATE <= FINISH;
												end
											end
									endcase

						
						//FINISH, iletim tamamlandýðýnda Break State geçiþi saðlar
						FINISH :
							begin
								transmit <= 1'b0;
								if (done == 1'b1)
								begin
									STATE <= BREAK;
									if (end_configure == 1'b1)
										done_configure <= 1'b1;
								end
							end
						
						/*BREAK state, iletimler arasýndaki zamanlama gereksinimlerini karþýlamak için
						 IDLE state ile arasýný gerektiðince uzun tutar. BREAK istenirse azaltýlabilir*/
						BREAK :
							if (break_count == 12'hFFF)
							begin
								break_count <= 12'h000;
//								baþlatma iþlemi iptal edildiyse (döngülerin
//								istenmeyen þekilde iletilmesini ve alýnmasýný 
//								önlemek için) ve bitiþ ile sample_done high ise, 
//								istenen eylemin tamamlandýðýný gösterir
								
								if ((finish == 1'b1 | sample_done == 1'b1) & start == 1'b0)
								begin
									STATE <= IDLE;
									txdata <= yAxis0;
								end
//								Eðer done_configure high ve sample_done low ise alým tamamlanmamýþtýr,
//								bu nedenle state TRANSMIT'e geri döner.
								else if (sample_done == 1'b1 & start == 1'b1)
									STATE <= HOLD;
								else if (done_configure == 1'b1 & sample_done == 1'b0)
								begin
									STATE <= TRANSMIT;
									transmit <= 1'b1;
								end
								//Eðer sistem konfigürasyon iþlemi bitmediyse,
								//döngü CONFIGURE state geri döner
								else if (done_configure == 1'b0)
									STATE <= CONFIGURE;
							end
							else
								break_count <= break_count + 1'b1;
						HOLD :
							if (hold_count == 24'h1FFFFF)
							begin
								hold_count <= 21'd0;
								STATE <= TRANSMIT;
								sample_done <= 1'b0;
							end
							else if (start <= 1'b0)
							begin
								STATE <= IDLE;
								hold_count <= 21'd0;
							end
							else begin
								hold_count <= hold_count + 1'b1;
							end
					endcase
			end
		end
   
endmodule

