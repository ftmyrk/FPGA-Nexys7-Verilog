/*baudrate'imizin 9600 olduðunu var sayarsak. Benim FPGA Clock'un hýzý da 100Mhz. 
"TICKS" in UART sinyalinin frekansýnýn 16 kez gelmesini istiyorsak
9600 Hz'nin 16 katý frekansa ihtiyacýmýz var. 
The width of the UART signal is 1/9600 equal to 104us. Esas Clock geniþliði  1 / 100Mhz'dir o da 10ns'ye eþittir.
Yani (104000ns/16)/ 10ns = 650 pulse olur (Top Module de baudrate'i 650 yazmamýz sebebi buydu.)
*/
module UART_BaudRate_generator(
    input Clk,
    input Rst_n,
    output Tick,
    input [15:0]BaudRate,
    output transmit,
    input btn1
    );

reg [15:0] baudRateReg;
reg [15:0] count; 
reg ff1=1'b0;
wire ff2;

always @ (posedge Clk)
begin
if(btn1 & !ff1)
ff1 <= 1'b1;
else if(btn1 & ff1)
ff1 <= 1'b0;
end

assign ff2 = (btn1 || ff1);

always @(posedge Clk)
    if (Rst_n) baudRateReg <= 16'b1;
    else if (Tick) baudRateReg <= 16'b1;
         else baudRateReg <= baudRateReg + 1'b1;
assign Tick = (baudRateReg == BaudRate);

always @(posedge Clk & ff2)
begin
if (transmit) 
count <= 16'b1;
else 
count <= count + 1'b1;
end

assign transmit = (count == BaudRate);
endmodule   

