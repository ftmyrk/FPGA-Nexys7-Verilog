//    Spi_master, t�m aray�z�n durumunu kontrol eder. 
//    Ba�ka mod�llerle etkile�im kurabilmek i�in bir tak�m sinyaller kullanmak gerekir.
//    Spi_master, iletilecek verileri se�er ve PmodACL'den al�nan t�m verileri saklar.

module SPImaster(
   input            rst,            //Reset sinyali
   input            clk,            //FPGA clock 100Mhz
   input            start,
   input            done,           //Tamamlanm�� iletim sonucu g�nderilen sinyal  
   input [7:0]      rxdata,         //Recieve Data
   output reg      transmit,        //iletimin ba�lang�c� i�in g�nderilen sinyal
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
   
   //Configurasyon Register Yap�land�rma
   //POWER_CTL Bits 0x2D
   parameter [15:0] POWER_CTL = 16'h2D08;
   //BW_RATE Bits 0x2C
   parameter [15:0] BW_RATE = 16'h2C08;
   //CONFIG Bits 0x31
   parameter [15:0] DATA_FORMAT = 16'h3100;
   
   //Eksen (Axis) Registerlar�, tek baytl�k art��larla sadece okuma yapma �zerine ayarland�
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
				// Geri D�nd�rme Ba�lat Butonu
				prevstart <= {prevstart[2:0], start};
				//Reset �artlar�
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
					//Main State, genel sistemin ne yapaca��n� se�er
					case (STATE)
						IDLE :
							//Sistem Configure edilmemi�se configure state'e girer
							if (done_configure == 1'b0) begin
								STATE <= CONFIGURE;
								txdata <= POWER_CTL;
								transmit <= 1'b1;
							end
							//E�er configure edilmi�se, start sinyali geldi�inde transmission state'e ge�er
							else if (prevstart == 4'b0011 & start == 1'b1 & done_configure == 1'b1) begin
								STATE <= TRANSMIT;
								finish <= 1'b0;
								txdata <= yAxis0;
								sample_done <= 1'b0;
							end
						CONFIGURE :
							case (CONFIGUREsel)
								//G�� kontrol adresini istenen konfig�rasyon biti g�nderilir
								powerCtl : begin
										STATE <= FINISH;
										CONFIGUREsel <= bwRate;
										transmit <= 1'b1;
									end
								//Band geni�li�i adresini istenen Konfig�rasyon biti g�nderilir
								bwRate : begin
										txdata <= BW_RATE;
										STATE <= FINISH;
										CONFIGUREsel <= dataFORMAT;
										transmit <= 1'b1;
									end
								//data format adresini istenen konfig�rasyon biti g�nderilir
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
											
						//Receive, verilerin spi_master'a ak���n� kontrol eder
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

						
						//FINISH, iletim tamamland���nda Break State ge�i�i sa�lar
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
						
						/*BREAK state, iletimler aras�ndaki zamanlama gereksinimlerini kar��lamak i�in
						 IDLE state ile aras�n� gerekti�ince uzun tutar. BREAK istenirse azalt�labilir*/
						BREAK :
							if (break_count == 12'hFFF)
							begin
								break_count <= 12'h000;
//								ba�latma i�lemi iptal edildiyse (d�ng�lerin
//								istenmeyen �ekilde iletilmesini ve al�nmas�n� 
//								�nlemek i�in) ve biti� ile sample_done high ise, 
//								istenen eylemin tamamland���n� g�sterir
								
								if ((finish == 1'b1 | sample_done == 1'b1) & start == 1'b0)
								begin
									STATE <= IDLE;
									txdata <= yAxis0;
								end
//								E�er done_configure high ve sample_done low ise al�m tamamlanmam��t�r,
//								bu nedenle state TRANSMIT'e geri d�ner.
								else if (sample_done == 1'b1 & start == 1'b1)
									STATE <= HOLD;
								else if (done_configure == 1'b1 & sample_done == 1'b0)
								begin
									STATE <= TRANSMIT;
									transmit <= 1'b1;
								end
								//E�er sistem konfig�rasyon i�lemi bitmediyse,
								//d�ng� CONFIGURE state geri d�ner
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

