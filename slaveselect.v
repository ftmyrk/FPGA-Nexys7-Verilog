module slaveSelect(
   input   rst,
   input   clk,
   input   transmit,
   input   done,
   output reg ss= 1'b1  
);


		always @(posedge clk)
		begin: ssprocess
			
			begin
				//reset durumunda ss high olur 
				if (rst == 1'b1)
					ss <= 1'b1;
				//if transmit high olursa ss ise low olur 
				else if (transmit == 1'b1)
					ss <= 1'b0;
				//done high olursa ss de high olur 
				else if (done == 1'b1)
					ss <= 1'b1;
			end
		end
   
endmodule


