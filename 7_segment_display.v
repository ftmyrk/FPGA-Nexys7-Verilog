`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.08.2020 10:19:38
// Design Name: 
// Module Name: 7sd
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


module seven_segment_d(
    input [7:0] data, //gelen data
    input clk,        // Sistem clock
    output reg [3:0] dig, // kullanacağımız "7 segment display" sayısı 
    output reg [6:0] seg  // kullacağımız segment sayısı 7 tane
    );
    
    reg [3:0] hundreds; //yüzler basamağı
    reg [3:0] tens;     //onlar basamağı
    reg [3:0] ones;     //birler basamğı
    reg[3:0] a=0;       //case geçleri için kullanılan register
    
 parameter AN0=8'b11111110;     //ilk 7 segment display'İn adresi
 parameter AN1=8'b11111101;     //ikinci 7 segment display'in adresi
 parameter AN2 = 8'b11111011;   //üçüncü 7 segment display'in adresi
 parameter AN3 = 8'b11110111;   //döndürcü 7 segment display'in adresi
    
 parameter zero = 7'b1000000;  //7 segment'te 0'ın binary karşılığı
 parameter one = 7'b1111001;   //7 segment'te 1'ın binary karşılığı
 parameter two = 7'b0100100;   //7 segment'te 2'ın binary karşılığı
 parameter three = 7'b0110000; //7 segment'te 3'ın binary karşılığı
 parameter four = 7'b0011001;  //7 segment'te 4'ın binary karşılığı
 parameter five = 7'b0010010;  //7 segment'te 5'ın binary karşılığı
 parameter six = 7'b0000010;   //7 segment'te 6'ın binary karşılığı
 parameter seven = 7'b1111000; //7 segment'te 7'ın binary karşılığı
 parameter eigth = 7'b0000000; //7 segment'te 8'ın binary karşılığı
 parameter nine = 7'b0010000;  //7 segment'te 9'ın binary karşılığı

    integer i;

always @(posedge clk) 
begin
hundreds=4'b0;
tens=4'b0;
ones=4'b0;

for(i=7;i>=0;i=i-1) //binary'İ decimale çevirdiğimiz if bloğu
begin
    if(hundreds>=5)hundreds=hundreds+3;
    if(tens>=5)tens=tens+3;
    if(ones>=5)ones=ones+3;
    
    hundreds=hundreds<<1;
    hundreds[0]=tens[3];
    tens=tens<<1;
    tens[0]=ones[3];
    ones=ones<<1;
    ones[0]=data[i];
end

if(a==4)        //toplam 4 tane case var bu yüzden 4 kere loop yapılacaktır.
a=0;            
else 
a<=a+1'd1; 

               case(a)  
3:begin  
                    case(hundreds [3:0])  
                    0 : seg <= zero;   
                    1 : seg <= one;  
                    2 : seg <= two;  
                    3 : seg <= three;  
                    4 : seg <= four;  
                    5 : seg <= five;  
                    6 : seg <= six;  
                    7 : seg <= seven;  
                    8 : seg <= eigth;  
                    9 : seg <= nine;  
                    default:seg <= 7'b1111111;  
                    endcase  
                    dig <= AN3;  
                 end  
2:begin  
                    case(tens [3:0])  
                    0 : seg <= zero;  
                    1 : seg <= one;  
                    2 : seg <= two;  
                    3 : seg <= three;  
                    4 : seg <= four;  
                    5 : seg <= five;  
                    6 : seg <= six;  
                    7 : seg <= seven;  
                    8 : seg <= eigth;  
                    9 : seg <= nine;  
                    default:seg <= 7'b1111111;  
                  endcase  
                    dig <= AN2;  
                 end
1:begin
                  case(ones [3:0])  
                    0 : seg <= zero;  
                    1 : seg <= one;  
                    2 : seg <= two;  
                    3 : seg <= three;  
                    4 : seg <= four;  
                    5 : seg <= five;  
                    6 : seg <= six;  
                    7 : seg <= seven;  
                    8 : seg <= eigth;  
                    9 : seg <= nine;  
                    default:seg <= 7'b1111111;  
                  endcase  
                     dig <= AN1;             
               end
0:begin
                       seg <= 7'b1000110; 
                        dig <= AN0; 
                        end
            endcase
            end      
endmodule
