
module TopModuleSPI(
   input        CLK,
   input        RST,
   input        START,
   input        SDI,
   output       SDO,
   output       SCLK,
   output       SS,
   output [7:0] yAxis
);


   wire [15:0]  TxBuffer;
   wire [7:0]   RxBuffer;
   wire         doneConfigure;
   wire         done;
   wire         transmit;
   
		//SPI Arayüzünü Kontrol Eder, Alýnan Verileri Depolar ve Gönderilecek Verileri Kontrol eder
		SPImaster C0(.rst(RST), .start(START), .clk(CLK), .transmit(transmit), .txdata(TxBuffer), .rxdata(RxBuffer), .done(done), .y_axis_data(yAxis));
		
		//Zaman Sinyalleri üretir, ACL Verilerini Okur ve Verileri ACL'ye Yazar
		SPIinterface C1(.sdi(SDI), .sdo(SDO), .rst(RST), .clk(CLK), .sclk(SCLK), .txbuffer(TxBuffer), .rxbuffer(RxBuffer), .done_out(done), .transmit(transmit));
		
		slaveSelect C2(.clk(CLK), .ss(SS), .done(done), .transmit(transmit), .rst(RST));
   
endmodule
