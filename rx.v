module uart_rx (//Define my module as UART_rs232_rx
    input Clk,
    input Rst_n,
    output reg [7:0] RxData,//��kt�y� da kaydederiz, b�ylece de�eri saklar�z
    input Rx,
    input Tick);		//8 bit


parameter  IDLE = 1'b0, READ = 1'b1; 	//State Machine i�in 2 tane durum olu�turduk 0 ve 1 (READ ve IDLE)
reg [1:0] State, Next;			//Durum veya Ko�ullar i�in 2 tane register olu�turduk
reg  read_enable = 1'b0;		//Okumaya izin verip vermemesinin kayd�n� tuttuyoruz.
reg  start_bit = 1'b1;			//Ba�lang�� biti alg�land���nda bildirimde bulunmak i�in kullan�lan de�i�ken (RX'in ilk falling edge)
reg [4:0]Bit = 5'b00000;		//Bit bit okumak i�in kullan�lan de�i�ken (bu durumda 8 bit yani 8 d�ng�)
reg [3:0] counter = 4'b0000;		//Counter de�i�keni Tick'in 16 kere tetiklenmesi i�in kullan�yoruz.
reg [7:0] Read_data= 8'b00000000;	//Rx giri� bitlerini RxData ��k���na atamadan �nce nerede saklad���m�z� kaydedin
reg RxEn = 1'b1;
reg RxDone;  //Veri okuma i�lemi bitti�inde bildirimde bulunmak i�in kullan�lan de�i�ken
reg NBits = 4'b1000	;
////////////////////////////////////////////////////////////////////////////
//                          STATE MACHINE                                 //
//                              Reset                                     //
////////////////////////////////////////////////////////////////////////////
always @ (posedge Clk)			//Reset blo�u
begin
if (Rst_n)	State <= IDLE;				
else 		State <= Next;				
end

////////////////////////////////////////////////////////////////////////////
//                                                                       ///
////////////////////////////////////////////////////////////////////////////
/*blo�un i�ine her "State or Rx or RxEn or RxDone" de�eri de�i�ti�inde i�ine girer.
	- A��k�as� IDLE'ye yaln�zca RxDone high oldu�unda ula��r�z
okuma i�leminin tamamland��� anlam�na gelir.
	- Ayr�ca, IDLE'in i�indeyken, READ durumuna ge�ebilmek i�in sadece Rx giri�i low olursa
bir ba�lang�� biti tespit etmi� oluruz*/
always @ (State or Rx or RxEn or RxDone)
begin
    case(State)	
	IDLE:	if(!Rx & RxEn)		Next = READ;	 //E�er Rx low olursa (yani Start biti belirlenmi�) okuma (READ) i�lemine ge�iyor olacaz
		else			Next = IDLE;
	READ:	if(RxDone)		Next = IDLE; 	 //E�er RxDone high olursa, IDLE durumuna ge�eriz ve Rx inputu low olana kadar bekler (yani Start bitini beklemi� oluyoruz)
		else			Next = READ;
	default 			Next = IDLE;
    endcase
end
////////////////////////////////////////////////////////////////////////////
//                          READ(OKUMA) / IDLE(BO�TA)                     //
////////////////////////////////////////////////////////////////////////////
always @ (State or RxDone)
begin
    case (State)
	READ: begin
		read_enable <= 1'b1;			
	      end
	      // READ durumundaysak, okuma s�recini etkinle�tiririz, b�ylece "Her zaman Tick sinyaliyle"  bitleri almaya ba�lar�z
	IDLE: begin
		read_enable <= 1'b0;			
	      end
    endcase 
end

////////////////////////////////////////////////////////////////////////////
///////////////////////////Read the input data//////////////////////////////
////////////////////////////////////////////////////////////////////////////
/*Her Tick sinyali geldi�inde sayac� bir artt�r�z.
- Saya� 8 (4'b1000) e�it oldu�unda START bitin ortas�nda olmu� oluruz
- Saya� 16 (4'b1111) e�it oldu�unda di�er bitlerin ortas�nda olmu� oluruz.
- Read_data Register'a Rx input bitini Shiftleyerek register�n i�ine kaydetmi� oluruz. 
*/
always @ (posedge Tick)

	begin
	if (read_enable)
	begin
	RxDone <= 1'b0;							//��lem s�resince RxDone low'a ayarlan�r.
	counter <= counter+1;						//Her Tick sinyali geldi�inde sayac� bir artt�r�yoruz	

	if ((counter == 4'b1000) & (start_bit))				 
	begin
	start_bit <= 1'b0;
	counter <= 4'b0000;
	end

	if ((counter == 4'b1111) & (!start_bit) & (Bit < NBits))	//8 bitlik okuma yapmak i�in 8 kere d�ng� olu�tururuz.
	begin
	Bit <= Bit+1;
	Read_data <= {Rx,Read_data[7:1]};
	counter <= 4'b0000;
	end
	
	if ((counter == 4'b1111) & (Bit == NBits)  & (Rx))		//Sonra bir kez daha 16'ya kadar sayar�z ve STOP bitini tespit ederiz (Rx inputu high olmal�d�r)
	begin
	Bit <= 4'b0000;
	RxDone <= 1'b1;
	counter <= 4'b0000;
	start_bit <= 1'b1;						//Sonraki data giri�i i�in t�m de�erleri s�f�rl�yoruz ve RxDone'u high olarak ayarl�yoruz
	end
	end
	
	

end
/////////////////////////////////////////////////////////////////////
/*Finally, Read_data Register'�n de�erlerini RxData outputuna atar�z ve
bu bizim ald���m�z son de�er olur.*/
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

