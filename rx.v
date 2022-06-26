module uart_rx (//Define my module as UART_rs232_rx
    input Clk,
    input Rst_n,
    output reg [7:0] RxData,//Çýktýyý da kaydederiz, böylece deðeri saklarýz
    input Rx,
    input Tick);		//8 bit


parameter  IDLE = 1'b0, READ = 1'b1; 	//State Machine için 2 tane durum oluþturduk 0 ve 1 (READ ve IDLE)
reg [1:0] State, Next;			//Durum veya Koþullar için 2 tane register oluþturduk
reg  read_enable = 1'b0;		//Okumaya izin verip vermemesinin kaydýný tuttuyoruz.
reg  start_bit = 1'b1;			//Baþlangýç biti algýlandýðýnda bildirimde bulunmak için kullanýlan deðiþken (RX'in ilk falling edge)
reg [4:0]Bit = 5'b00000;		//Bit bit okumak için kullanýlan deðiþken (bu durumda 8 bit yani 8 döngü)
reg [3:0] counter = 4'b0000;		//Counter deðiþkeni Tick'in 16 kere tetiklenmesi için kullanýyoruz.
reg [7:0] Read_data= 8'b00000000;	//Rx giriþ bitlerini RxData çýkýþýna atamadan önce nerede sakladýðýmýzý kaydedin
reg RxEn = 1'b1;
reg RxDone;  //Veri okuma iþlemi bittiðinde bildirimde bulunmak için kullanýlan deðiþken
reg NBits = 4'b1000	;
////////////////////////////////////////////////////////////////////////////
//                          STATE MACHINE                                 //
//                              Reset                                     //
////////////////////////////////////////////////////////////////////////////
always @ (posedge Clk)			//Reset bloðu
begin
if (Rst_n)	State <= IDLE;				
else 		State <= Next;				
end

////////////////////////////////////////////////////////////////////////////
//                                                                       ///
////////////////////////////////////////////////////////////////////////////
/*bloðun içine her "State or Rx or RxEn or RxDone" deðeri deðiþtiðinde içine girer.
	- Açýkçasý IDLE'ye yalnýzca RxDone high olduðunda ulaþýrýz
okuma iþleminin tamamlandýðý anlamýna gelir.
	- Ayrýca, IDLE'in içindeyken, READ durumuna geçebilmek için sadece Rx giriþi low olursa
bir baþlangýç biti tespit etmiþ oluruz*/
always @ (State or Rx or RxEn or RxDone)
begin
    case(State)	
	IDLE:	if(!Rx & RxEn)		Next = READ;	 //Eðer Rx low olursa (yani Start biti belirlenmiþ) okuma (READ) iþlemine geçiyor olacaz
		else			Next = IDLE;
	READ:	if(RxDone)		Next = IDLE; 	 //Eðer RxDone high olursa, IDLE durumuna geçeriz ve Rx inputu low olana kadar bekler (yani Start bitini beklemiþ oluyoruz)
		else			Next = READ;
	default 			Next = IDLE;
    endcase
end
////////////////////////////////////////////////////////////////////////////
//                          READ(OKUMA) / IDLE(BOÞTA)                     //
////////////////////////////////////////////////////////////////////////////
always @ (State or RxDone)
begin
    case (State)
	READ: begin
		read_enable <= 1'b1;			
	      end
	      // READ durumundaysak, okuma sürecini etkinleþtiririz, böylece "Her zaman Tick sinyaliyle"  bitleri almaya baþlarýz
	IDLE: begin
		read_enable <= 1'b0;			
	      end
    endcase 
end

////////////////////////////////////////////////////////////////////////////
///////////////////////////Read the input data//////////////////////////////
////////////////////////////////////////////////////////////////////////////
/*Her Tick sinyali geldiðinde sayacý bir arttýrýz.
- Sayaç 8 (4'b1000) eþit olduðunda START bitin ortasýnda olmuþ oluruz
- Sayaç 16 (4'b1111) eþit olduðunda diðer bitlerin ortasýnda olmuþ oluruz.
- Read_data Register'a Rx input bitini Shiftleyerek registerýn içine kaydetmiþ oluruz. 
*/
always @ (posedge Tick)

	begin
	if (read_enable)
	begin
	RxDone <= 1'b0;							//Ýþlem süresince RxDone low'a ayarlanýr.
	counter <= counter+1;						//Her Tick sinyali geldiðinde sayacý bir arttýrýyoruz	

	if ((counter == 4'b1000) & (start_bit))				 
	begin
	start_bit <= 1'b0;
	counter <= 4'b0000;
	end

	if ((counter == 4'b1111) & (!start_bit) & (Bit < NBits))	//8 bitlik okuma yapmak için 8 kere döngü oluþtururuz.
	begin
	Bit <= Bit+1;
	Read_data <= {Rx,Read_data[7:1]};
	counter <= 4'b0000;
	end
	
	if ((counter == 4'b1111) & (Bit == NBits)  & (Rx))		//Sonra bir kez daha 16'ya kadar sayarýz ve STOP bitini tespit ederiz (Rx inputu high olmalýdýr)
	begin
	Bit <= 4'b0000;
	RxDone <= 1'b1;
	counter <= 4'b0000;
	start_bit <= 1'b1;						//Sonraki data giriþi için tüm deðerleri sýfýrlýyoruz ve RxDone'u high olarak ayarlýyoruz
	end
	end
	
	

end
/////////////////////////////////////////////////////////////////////
/*Finally, Read_data Register'ýn deðerlerini RxData outputuna atarýz ve
bu bizim aldýðýmýz son deðer olur.*/
always @ (posedge Clk)
begin

if (NBits == 4'b1000)
begin
RxData[7:0] <= Read_data[7:0];	
end

if (NBits == 4'b0111)
begin
RxData[7:0] <= {1'b0,Read_data[7:1]};	

end

if (NBits == 4'b0110)
begin
RxData[7:0] <= {1'b0,1'b0,Read_data[7:2]};		

end
end


endmodule

