//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 22.07.2020 11:47:39
//// Design Name: 
//// Module Name: Top_Module
//// Project Name: 
//// Target Devices: 
//// Tool Versions: 
//// Description: 
//// 
//// Dependencies: 
//// 
//// Revision:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////////////////////////////////////////////////////////////////////////////////////


module top(
input btn0,
input btn1,
input clk,
input Rx,
output [7:0] RxData,
/////////////////////////
input [7:0] TxData,
output TxD,
/////////////////////////
input sw1,
inout sda,
output scl,
output [15:0] dis_data,
/////////////////////////
input [7:0] seg_data,
output [6:0] seg,
output [7:0] dig
); 
   
wire tick;     // Baud rate clock
wire [15:0] BaudRate; 
wire transmit;

///////////////////////////////////////////////////////////////////////////////////////////
assign 		BaudRate = 16'd650; 	

////////////////////////////////////////////////////////////////////////////////////////////
transmitter T1 (.clk(clk), .reset(btn0),.transmit(transmit),.TxD(TxD),.TxData(TxData));

uart_rx R3 (.Clk(clk), .Rst_n(btn0), .RxEn(RxEn), .RxData(RxData), .Rx(Rx), .Tick(tick));

UART_BaudRate_generator BG(.Clk(clk), .Rst_n(btn0), .Tick(tick), .BaudRate(BaudRate), .transmit(transmit), .btn1(btn1));

i2c_temp Temp(.sda(sda), .scl(scl), .dis_data(dis_data), .clk(clk), .rst_n(btn0), .sw1(sw1));

seven_s segment(.clk(clk), .seg(seg), .dig(dig), .data(seg_data));


endmodule