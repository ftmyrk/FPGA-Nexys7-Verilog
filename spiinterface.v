module SPIinterface(
   input            clk,            //100 MHz clock sinyali
   input            rst,            //Reset giriþ sinyali
   input            transmit,       //SPImaster'dan gelen iletim sinyali
   input            MISO,           //Master In Slave Out
   input  [15:0]    txbuffer,       //SPImaster'dan gelen sinyali tutar
   output [7:0]     rxbuffer,
   output           done_out,
   output   reg     MOSI,           //Master Out Slave In
   output           SCLK            //SPI clock
);
   
  
   parameter [7:0]  CLKDIVIDER = 8'hFF;		//SCLK 98kHz olmasý saðlar

   parameter [1:0]  TxIDLE = 0,
                    TRANSMIT = 1;

   parameter [1:0]  RxIDLE = 0,
                    RECIEVE = 1;

   parameter [1:0]  Clk_IDLE = 0,
                    RUN = 1;
						  
   reg [7:0]        clk_count = 7'd0;
   reg              clk_edge_buffer = 1'd0;
   
   reg              sck_previous = 1'b1;
   reg              sck_buffer = 1'b1;
   
   reg [15:0]       tx_shift_register = 16'h0000;
   reg [3:0]        tx_count = 4'h0;
   reg [7:0]        rx_shift_register = 8'h00;
   reg [3:0]        rx_count = 4'h0;

   reg              done = 1'b0;
   reg [1:0]        TxSTATE = TxIDLE;
   reg [1:0]        RxSTATE = RxIDLE;
   reg [1:0]        SCLKSTATE = TxIDLE;
   
   
   
   
		always @(posedge clk)
		begin: TxProcess
			//Reset state
			
			begin
				if (rst == 1'b1)
				begin
					tx_shift_register <= 16'd0;
					tx_count <= 4'd0;
					MOSI <= 1'b1;
					TxSTATE <= TxIDLE;
				end
				else
					case (TxSTATE)
						//IDLE olduðunda, Transmitting (iletim) High olursa, state Transmitting'e geçer.
					    // IDLE state sýrasýnda, MOSI High'da tutulur
						
						TxIDLE :
							begin
								tx_shift_register <= txbuffer;
								//MOSI<='1';
								if (transmit == 1'b1)
									TxSTATE <= TRANSMIT;
								else if (done == 1'b1)
									MOSI <= 1'b1;
							end
						TRANSMIT :
							if (sck_previous == 1'b1 & sck_buffer == 1'b0)
							begin
					           	//Sayaç 15'e geldiðinde IDLE state geri döner. 
								//Aksi takdirde, TxData düþen kenarda (falling edge) shift iþlemi yapar.
								if (tx_count == 4'b1111) begin
									TxSTATE <= TxIDLE;
									tx_count <= 4'd0;
									MOSI <= tx_shift_register[15];
								end
								else begin
									tx_count <= tx_count + 4'b0001;
									MOSI <= tx_shift_register[15];
									tx_shift_register <= {tx_shift_register[14:0], 1'b0};
								end
							end
					endcase
			end
		end
		
		
		
		
		always @(posedge clk)
		begin: RxProcess
			//Reset state
			
			begin
				if (rst == 1'b1)
				begin
					rx_shift_register <= 8'h00;
					rx_count <= 4'h0;
					done <= 1'b0;
					RxSTATE <= RxIDLE;
				end
				else
					case (RxSTATE)
						RxIDLE :
						
							//SPImaster'dangelen transmit High olduðunda,
							//State RECIEVE durumuna geçer ve rx_shift_register 0 olur.
							if (transmit == 1'b1)
							begin
								RxSTATE <= RECIEVE;
								rx_shift_register <= 8'h00;
							end
							else if (SCLKSTATE == RxIDLE)
								done <= 1'b0;
						RECIEVE :
							if (sck_previous == 1'b0 & sck_buffer == 1'b1)
							begin
								//MISO, yükselen kenarda data akýþýný saðlar. 
								//16 kere yükselen kenar geldikten sonra IDLE state durumuna geçer
								// ve done high olur.
								if (rx_count == 4'b1111)
								begin
									RxSTATE <= RxIDLE;
									rx_count <= 4'd0;
									rx_shift_register <= {rx_shift_register[6:0], MISO};
									done <= 1'b1;
								end
								else
								begin
									rx_count <= rx_count + 4'd1;
									rx_shift_register <= {rx_shift_register[6:0], MISO};
								end
							end
					endcase
			end
		end
		
		//-------------------------------------------------------------------------
		//		 			 					Serial Clock
		//-------------------------------------------------------------------------
		always @(posedge clk)
		begin: SCLKgen
			begin
				if (rst == 1'b1)
				begin
					clk_count <= 8'h00;
					SCLKSTATE <= Clk_IDLE;
					sck_previous <= 1'b1;
					sck_buffer <= 1'b1;
				end
				else
					case (SCLKSTATE)
						Clk_IDLE :
							begin
								sck_previous <= 1'b1;
								sck_buffer <= 1'b1;
								clk_count <= 8'h00;
								clk_edge_buffer <= 1'b0;
								
								//transmit high olduðunda state RUN duurumuna geçer
								if (transmit == 1'b1)
								begin
									SCLKSTATE <= RUN;
								end
							end
						RUN :
							//done high olduðunda state IDLE durumuna geri döner
							if (done == 1'b1) begin
								SCLKSTATE <= Clk_IDLE;
							end
							//Eðer done tetiklenmediyse, saat saymaya devam eder
							else if (clk_count == CLKDIVIDER) begin
								if (clk_edge_buffer == 1'b0) begin
									sck_buffer <= 1'b1;
									clk_edge_buffer <= 1'b1;
								end
								else begin
									sck_buffer <= (~sck_buffer);
									clk_count <= 8'h00;
								end
							end
							else begin
								sck_previous <= sck_buffer;
								clk_count <= clk_count + 1'b1;
							end
					endcase
			end
		end
		
		assign rxbuffer = rx_shift_register;
		assign SCLK = sck_buffer;
		assign done_out = done;
   
endmodule


