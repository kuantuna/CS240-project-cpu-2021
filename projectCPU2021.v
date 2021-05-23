module projectCPU2021(
  clk,
  rst,
  wrEn,
  data_fromRAM,
  addr_toRAM,
  data_toRAM,
  PC,
  W
);

input clk, rst;

input wire [15:0] data_fromRAM;
output reg [15:0] data_toRAM;
output reg wrEn;

// 12 can be made smaller so that it fits in the FPGA
output reg [12:0] addr_toRAM;
output reg [12:0] PC; // This has been added as an output for TB purposes
output reg [15:0] W; // This has been added as an output for TB purposes

// Your design goes in here
reg [15:0] num, numNext;
reg [2:0]  opcode, opcodeNext;
reg [12:0] operand, operandNext;
reg [12:0] PCnext;
reg [2:0]  state, stateNext;
reg [15:0] Wnext;

always @(posedge clk) begin
	num     <= #1 numNext;
	opcode  <= #1 opcodeNext;
	operand <= #1 operandNext;
	PC      <= #1 PCnext;
	state   <= #1 stateNext;
	W       <= #1 Wnext;
end

always @* begin
	addr_toRAM  = 0;
	data_toRAM  = 0;
	numNext     = num;
	opcodeNext  = opcode;
	operandNext = operand;
	PCnext      = PC;
	stateNext   = state;
	Wnext       = W;
	wrEn        = 0;
	
	if(rst) begin
		addr_toRAM  = 0;
		data_toRAM  = 0;
		numNext     = 0;
		opcodeNext  = 0;
		operandNext = 0;
		PCnext      = 0;
		stateNext   = 0;
		Wnext       = 0;	
		wrEn        = 0;	
	end
	
	case(state)
		0: begin                                // --- REQUEST THE INSTRUCTION POINTED BY PC ---
			data_toRAM  = 0;                    // There won't be any write operation,      	DEFAULT.
			numNext     = 0;                    // No data has been retrieved,              	DEFAULT.
			opcodeNext  = opcode;               // Opcode hasn't been retrieved,            	DEFAULT.
			operandNext = operand;              // Operand hasn't been retrieved,           	DEFAULT.
			
			addr_toRAM  = PC;                   // In order to read instruction pointed by PC.
			PCnext      = PC;                   // PC is not going to change.
			Wnext       = W;                    // W is not going to change.
			wrEn        = 0;                    // Making sure that we're reading from memory.
			
			stateNext   = 1;                    // Next state is 1.                 0 -> 1
		end
		
		
		1: begin                                 // --- GET THE OPCODE AND OPERAND OF THE INSTRUCTION, REQUEST NUMBER (DATA) ---
			data_toRAM  = 0;                     // There won't be any write operation,      	DEFAULT.
			numNext     = 0;                     // No data has been retrieved,              	DEFAULT.
			
			addr_toRAM  = data_fromRAM[12:0];    // In order to read the data (number) inside the operand.
			opcodeNext  = data_fromRAM[15:13];   // Get opcode.
			operandNext = data_fromRAM[12:0];    // Get operand.
			PCnext      = PC;                    // PC is not going to change.
			Wnext       = W;                     // W is not going to change.
			wrEn        = 0;                     // Making sure that we're reading from memory.
			
			if(operandNext == 0) begin			 // IF: operand is 0 then indirection will be done.
				if(opcodeNext == 3'b110)
					stateNext = 7;				 // CPfW
				else if(opcodeNext == 3'b100 || opcodeNext == 3'b111)
					stateNext = 6;				 // SZ or JMP
				else
					stateNext = 5;				 // ADD or NAND or SRRL or GE or CP2W
			end									 // ------------------------------------------------

			else begin							 // ELSE: normal instructions will be performed.
				if(opcodeNext == 3'b110)
					stateNext = 4;				 // CPfW
				else if(opcodeNext == 3'b100 || opcodeNext == 3'b111)
					stateNext = 3;				 // SZ or  JMP
				else
					stateNext = 2;				 // ADD or NAND or SRRL or GE or CP2W
			end								 	 // ------------------------------------------------
		end
		
		
		2: begin								 // --- GET NUMBER (DATA), PERFORM -ADD, NAND, SRRL, GE, CP2W- INSTRUCTIONS ---   UPDATES W
			addr_toRAM = 0;                  	 // We neither read nor write to the memory, 	DEFAULT.
			data_toRAM = 0;                  	 // There won't be any write operation,      	DEFAULT.

			numNext     = data_fromRAM;          // Get number pointed by operand.
			opcodeNext  = opcode;                // Opcode is not going to change.
			operandNext = operand;               // Operand is not going to change.
			PCnext      = PC + 1;             	 // Last step of the instruction.
			wrEn        = 0;                  	 // Making sure that we're not writing to "memory".
			
			if(opcode == 3'b000)           		 // ADD  =>                          W = W + *A
				Wnext = W + numNext;
			
			else if(opcode == 3'b001)     		 // NAND =>                          W = ~(W & (*A))
				Wnext = ~(W & numNext);
			
			else if(opcode == 3'b010) begin      // SRRL =>							 if((*A) is less than 16) W = W >> (*A)
												 //									 else if((*A) is between 16 and 31) W = W << lower4bits(*A)
												 //									 else if((*A) is between 32 and 47) W = RotateRight W by lower4bits(*A)
												 //									 else W = RotateLeft W by lower4bits(*A)
				if(numNext < 16)
					Wnext = W >> numNext;
				else if(numNext > 16 && numNext < 31)
					Wnext = W << numNext[3:0];
				else if(numNext > 32 && numNext < 47)
					// ROTATE RIGHT BY LOWER 4 BITS OF NUMNEXT
				else
					// ROTATE LEFT BY LOWER 4 BITS OF NUMNEXT
			end
			
			else if(opcode == 3'b011)     		 // GE   =>                          W = W >= (*A)
				Wnext = W >= numNext;
			
			else if(opcode == 3'b101)     		 // CP2W =>                          W = *A
				Wnext = numNext;
			
			stateNext = 0;                       // Next state is 0.                 2 -> 0
		end
		
		
		3: begin								 // --- GET NUMBER (DATA), PERFORM -SZ, JMP- INSTRUCTIONS ---					  UPDATES PC
			addr_toRAM = 0;                  	 // We neither read nor write to the memory, 	DEFAULT.
			data_toRAM = 0;                  	 // There won't be any write operation,      	DEFAULT.

			numNext     = data_fromRAM;          // Get number pointed by operand.
			opcodeNext  = opcode;                // Opcode is not going to change.
			operandNext = operand;               // Operand is not going to change.
			Wnext       = W;					 // W is not going to change.
			wrEn        = 0;                  	 // Making sure that we're not writing to "memory".

			if(opcode == 3'b100)     			 // SZ								 PC = ((*A) == 0) ? (PC+2) : (PC+1)
				PCnext = (numNext == 0) ? (PC + 2) : (PC + 1);

			else if(opcode == 3'b111)     		 // JMP								 PC = lower13bits(*A)
				PCnext = numNext[12:0];

			stateNext = 0;						 // Next state is 0.                 3 -> 0
		end


		4: begin								 // --- PERFORM CPfW INSTRUCTION ---											  WRITES TO MEMORY
			numNext = 0;						 // Since it won't be used, no need to read it, DEFAULT.

			opcodeNext  = opcode;                // Opcode is not going to change.
			operandNext = operand;               // Operand is not going to change.
			PCnext      = PC + 1;             	 // Last step of the instruction.
			Wnext       = W;					 // W is not going to change.
			

			if(opcode == 3'b110) begin     		 // CPfW							 *A = W
				addr_toRAM = operand;			 // We will be writing to the memory pointed by the operand.
				data_toRAM = W;					 // We will be writing value of W to the memory.
				wrEn       = 1;                  // Making sure that we are writing to the memory.
			end

			stateNext = 0;						 // Next state is 0.                 4 -> 0
		end
	
	endcase
end

endmodule
