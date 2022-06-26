`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.07.2020 09:59:37
// Design Name: 
// Module Name: Transmitter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module transmitter(
input clk, //UART input clock
input reset, // reset sinyali
input transmit,
input [7:0] TxData, // Transmit (iletim) edilecek 8-bitlik data
output reg TxD // Transmitter 
//TxD reset halinde veya herhangi bir iletim olmadýðýnda high olacaktýr. 
    );

reg [3:0] bitcounter; //4 bitlik sayaç 10'a kadar
reg [13:0] counter; //14 bitlik sayaç baud rate sayacý, counter = clock / baud rate
reg state,nextstate; 
// Ýletim sýrasýnda 10 bitlik verinin Shiftlenmesi gerekir.
//Least Signaficant bit, "0" Binary deðeri (bir start biti) baþlatýlýr 
//Most Signaficant bit binary deðer "1" verilir
reg [9:0] rightshiftreg; 
reg shift; //shift sinyali
reg load; //load sinyali. 
//Datayý rightshift registerýna yüklemeye baþlar. Start ve Stop bitlerini ekler
reg clear; //clear sinyali (bitcounter resetlemek için) 


always @ (posedge clk) 
begin 
    if (reset) //reset ==1 
	   begin 
        state <=0; // State == IDLE (state = 0)
        counter <=0;  
        bitcounter <=0;
       end
    else begin
         counter <= counter + 1; //baud rate generator sayacý 
            if (counter >= 10415) //baudrate: 10416 = (0'dan 10415'e kadar)
               begin 
                  state <= nextstate; 
                  counter <=0; 
            	  if (load) rightshiftreg <= {1'b1,TxData,1'b0}; 
            	  //load sinyali geldiðinde datayý yükler.
		          if (clear) bitcounter <=0; // 
                  if (shift) 
                     begin 
                        rightshiftreg <= rightshiftreg >> 1; 
                      //Verileri lsb'den iletirken verileri Right Shift yapar.
                        bitcounter <= bitcounter + 1; 
                     end
               end
         end
end 

//state machine
always @ (posedge clk) //rising edge 
//always @ (state or bitcounter or transmit)
begin
    load <=0; 
    shift <=0; 
    clear <=0; 
    TxD <=1; 
    case (state)
        0: begin // IDLE
             if (transmit) begin 
             nextstate <= 1; //transmit state
             load <=1;
             shift <=0;
             clear <=0;
             end 
		else begin 
             nextstate <= 0; // IDLE
             TxD <= 1; 
             end
           end
        1: begin  // transmit state
             if (bitcounter >=10) begin 
             // iletim gerçekleþip gerçekleþmediðinin kontrolü yapýlýr. 
             //Eðer tamamlanýrsa,
             nextstate <= 0; // sonraki state IDLE
             clear <=1; // tüm sayaçlar sýfýrlanýr
             end 
		else begin // tamamlanmaz ise, 
             nextstate <= 1; // transmit state
             TxD <= rightshiftreg[0]; // data shiftlenerek TxD'ye gönderilir
             shift <=1; // shift iþlemin devam etmesi
             end
           end
         default: nextstate <= 0;                      
    endcase
end
endmodule