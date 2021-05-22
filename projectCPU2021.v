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
		0: begin                               // ---REQUEST THE INSTRUCTION POINTED BY PC---
			data_toRAM  = 0;                    // There won't be any write operation,      DEFAULT.
			numNext     = 0;                    // No data has been retrieved,              DEFAULT.
			opcodeNext  = opcode;               // Opcode hasn't been retrieved,            DEFAULT.
			operandNext = operand;              // Operand hasn't been retrieved,           DEFAULT.
			
			addr_toRAM  = PC;                   // In order to read instruction pointed by PC.
			PCnext      = PC;                   // PC is not going to change.
			Wnext       = W;                    // W is not going to change.
			wrEn        = 0;                    // Making sure that we're reading from memory.
			
			stateNext   = 1;                    // Next state is 1.                 0 -> 1
		end
		
		
		1: begin                               // ---GET THE OPCODE AND OPERAND OF THE INSTRUCTION, REQUEST NUMBER (DATA)---
			data_toRAM  = 0;                    // There won't be any write operation,      DEFAULT.
			numNext     = 0;                    // No data has been retrieved,              DEFAULT.
			
			addr_toRAM  = data_fromRAM[12:0];   // In order to read the data (number) inside the operand.
			opcodeNext  = data_fromRAM[15:13];  // Get opcode.
			operandNext = data_fromRAM[12:0];   // Get operand.
			PCnext      = PC;                   // PC is not going to change.
			Wnext       = W;                    // W is not going to change.
			wrEn        = 0;                    // Making sure that we're reading from memory.
			
			if(operandNext == 0)
				stateNext = 3;
			else
				stateNext = 2;
		end
		
		
		2: begin			
			numNext     = data_fromRAM;         // Get number pointed by operand.
			opcodeNext  = opcode;               // Opcode is not going to change.
			operandNext = operand;              // Operand is not going to change.
			
			if(opcode == 3'b000) begin          // ADD  =>                          W = W + *A
				addr_toRAM = 0;                  // We neither read nor write to the memory, DEFAULT.
			   data_toRAM = 0;                  // There won't be any write operation,      DEFAULT.
				PCnext     = PC + 1;             // Last step of the instruction.
				Wnext      = W + numNext;
				wrEn       = 0;                  // Making sure that we're not writing to "memory".
			end
			
			else if(opcode == 3'b001) begin     // NAND =>                          W = ~(W & (*A))
				addr_toRAM = 0;                  // We neither read nor write to the memory, DEFAULT.
			   data_toRAM = 0;                  // There won't be any write operation,      DEFAULT.
				PCnext     = PC + 1;             // Last step of the instruction.
				Wnext      = ~(W & numNext);
				wrEn       = 0;                  // Making sure that we're not writing to "memory".
			end
			
			else if(opcode == 3'b010) begin     // SRRL
				addr_toRAM = 0;                  // We neither read nor write to the memory, DEFAULT.
			   data_toRAM = 0;                  // There won't be any write operation,      DEFAULT.
				PCnext     = PC + 1;             // Last step of the instruction.
				wrEn       = 0;   
				if(numNext < 16)
					Wnext = W >> numNext;
				else if(numNext > 16 && numNext < 31)
					Wnext = W << numNext[3:0];
				else if(numNext > 32 && numNext < 47)
					// ROTATE RIGHT BY LOWER 4 BITS OF NUMNEXT
				else
					// ROTATE LEFT BY LOWER 4 BITS OF NUMNEXT
			end
			
			else if(opcode == 3'b011) begin     // GE   =>                          W = W >= (*A)
				addr_toRAM = 0;                  // We neither read nor write to the memory, DEFAULT.
			   data_toRAM = 0;                  // There won't be any write operation,      DEFAULT.
				PCnext     = PC + 1;             // Last step of the instruction.
				Wnext      = W >= numNext;
				wrEn       = 0;                  // Making sure that we're not writing to "memory".
			end
			
			else if(opcode == 3'b100) begin     // SZ
				addr_toRAM = 0;                  // We neither read nor write to the memory, DEFAULT.
			   data_toRAM = 0;                  // There won't be any write operation,      DEFAULT.
				Wnext      = W;
				wrEn       = 0;                  // Making sure that we're not writing to "memory".
				PCnext     = (numNext == 0) ? (PC + 2) : (PC + 1);
			end
			
			else if(opcode == 3'b101) begin     // CP2W =>                          W = *A
				addr_toRAM = 0;                  // We neither read nor write to the memory, DEFAULT.
			   data_toRAM = 0;                  // There won't be any write operation,      DEFAULT.
				PCnext     = PC + 1;             // Last step of the instruction.
				Wnext      = numNext;
				wrEn       = 0;                  // Making sure that we're not writing to "memory".
			end
			
			else if(opcode == 3'b110) begin     // CPfW
				addr_toRAM = operand;
				data_toRAM = W;
				PCnext     = PC + 1;             // Last step of the instruction.
				Wnext      = W;
				wrEn       = 1;                  // Making sure that we are writing to the memory.
			end
			
			else if(opcode == 3'b111) begin     // JMP
				addr_toRAM = 0;                  // We neither read nor write to the memory, DEFAULT.
			   data_toRAM = 0;                  // There won't be any write operation,      DEFAULT.
				PCnext     = numNext[12:0];
				Wnext      = W;
				wrEn       = 0;                  // Making sure that we're not writing to "memory".
			end
			
			stateNext = 0;                      // Next state is 0.                 2 -> 0
		end
		
		
		3: begin
			// INDIRECTION
		end
	
	endcase
end

endmodule
