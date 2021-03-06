//ex.v
`include "defs.v"

module ex(
	// from risc-v.v
	input wire rst,
	
	// from id_ex.v
	input wire[`InstAddrBus] pc_i,
	input wire[`AluOpBus] aluop_i,
	input wire[`AluFunct3Bus] alufunct3_i,
	input wire[`AluFunct7Bus] alufunct7_i,
	input wire[`RegBus] reg1_i,
	input wire[`RegBus] reg2_i,
	input wire[`RegBus] imm_i,		// 实际上只有S类, (-B类-) 要用到, 其他都可以用 reg1_i 和 reg2_i
	input wire[`RegAddrBus] wd_i,
	input wire wreg_i,
	
	// to ex_mem.v
	output reg[`AluOpBus] aluop_o,
	output reg[`AluFunct3Bus] alufunct3_o, // 这两句为 LOAD 和 STORE 准备
	output reg me_o,
	output reg[`MemAddrBus] maddr_o,
	output reg wreg_o,
	output reg[`RegAddrBus] wd_o,
	output reg[`RegBus] wdata_o,	// STORE 时代表写入储存器的值(但是wreg_o==0), 其他时候代表写入寄存器的值
	
	// to regfile.v --> forwarding
	output reg wreg_f,
	output reg[`RegAddrBus] wd_f,
	output reg[`RegBus] wdata_f
	
);

	//移位数
	wire[`RegAddrBus] shiftbits = reg2_i[4:0];
	//保存中间结果
	reg me;						// 指令是否要读写内存
	reg[`MemAddrBus] maddr;		// 指令读写内存的地址
	reg[`RegBus] logicout;		// 写入rd的值
	
	//运算 --- NOP当作ADDI处理(x 其实什么也不是. 因为 ZeroWord 不是 NOP 指令)
	always @ (*) begin
		if(rst == `RstEnable) begin
			me <= `MemDisable;
			maddr <= `NopMem;
			logicout <= `ZeroWord;
		end
		else begin
			me <= `MemDisable;
			maddr <= `NopMem;
			logicout <= `ZeroWord;
			
			case(aluop_i)
				`LUI : begin
					logicout <= reg1_i;
				end
				`AUIPC : begin
					logicout <= reg1_i + pc_i;
				end
				`JAL : begin
					logicout <= pc_i + 4;
				end
				`JALR : begin
					logicout <= pc_i + 4;					
				end
				// `BRANCH 不需要写寄存器或内存
				`LOAD : begin
					me <= `MemEnable;
					maddr <= reg1_i + imm_i;		//用imm是为了和STORE统一
					// case(alufunct3_i)
						// `LB : begin
							
						// end
						// `LH : begin
						
						// end
						// `LW : begin
						
						// end
						// `LBU : begin
						
						// end
						// `LHU : begin
						
						// end
					// endcase
				end
				`STORE : begin
					me <= `MemEnable;
					maddr <= reg1_i + imm_i;		//用imm是为了和STORE统一
					logicout <= reg2_i;
					// case(alufunct3_i)
						// `SB : begin
						
						// end
						// `SH : begin
						
						// end
						// `SW : begin
						
						// end
					// endcase
				end
				`EXE_IMM : begin
					case(alufunct3_i)
						`ADDI : begin
							logicout <= reg1_i + reg2_i;
						end
						`SLTI : begin
							if($signed(reg1_i) < $signed(reg2_i)) begin
								logicout <= `OneWord;
							end
							else begin
								logicout <= `ZeroWord;
							end
						end
						`SLTIU : begin
							if(reg1_i < reg2_i) begin
								logicout <= `OneWord;
							end
							else begin
								logicout <= `ZeroWord;
							end
						end
						`XORI : begin
							logicout <= reg1_i ^ reg2_i;
						end
						`ORI : begin
							logicout <= reg1_i | reg2_i;
						end
						`ANDI : begin
							logicout <= reg1_i & reg2_i;
						end
						`SLLI : begin
							logicout <= reg1_i << shiftbits;
						end
						`SRLI_SRAI : begin
							case(alufunct7_i)
								`SRLI : begin
									logicout <= reg1_i >> shiftbits;
								end
								`SRAI : begin
									logicout <= (reg1_i >> shiftbits) | ({32{1'b1}} << (`RegWidth - shiftbits));
								end
							endcase
						end
					endcase
				end
				`EXE : begin
					case(alufunct3_i)
						`ADD_SUB : begin
							case(alufunct7_i)
								`ADD : begin
									logicout <= $signed(reg1_i) + $signed(reg2_i);
								end
								`SUB : begin
									logicout <= $signed(reg1_i) - $signed(reg2_i);
								end
							endcase
						end
						`SLL : begin
							logicout <= reg1_i << shiftbits;
						end
						`SLT : begin
							if($signed(reg1_i) < $signed(reg2_i)) begin
								logicout <= `OneWord;
							end
							else begin
								logicout <= `ZeroWord;
							end					
						end
						`SLTU : begin
							if(reg1_i < reg2_i) begin
								logicout <= `OneWord;
							end
							else begin
								logicout <= `ZeroWord;
							end							
						end
						`XOR : begin
							logicout <= reg1_i ^ reg2_i;
						end
						`SRL_SRA : begin
							case(alufunct7_i)
								`SRL : begin
									logicout <= reg1_i >> shiftbits;
								end
								`SRA : begin
									logicout <= (reg1_i >> shiftbits) | ({32{1'b1}} << (`RegWidth - shiftbits));
								end
							endcase						
						end
						`OR : begin
							logicout <= reg1_i | reg2_i;
						end
						`AND : begin
							logicout <= reg1_i & reg2_i;
						end
					endcase
				end
				// `MEM : begin end
				// `SYSTEM : begin
					// case(alufunct3_i)
						// `ECALL_EBREAK : begin
						
						// end
						// `CSRRW : begin
						
						// end
						// `CSRRS : begin
						
						// end
						// `CSRRC : begin
						
						// end
						// `CSRRWI : begin
						
						// end
						// `CSRRSI : begin
						
						// end
						// `CSRRCI : begin
						
						// end
					// endcase
				// end
				default: begin
					logicout <= `ZeroWord;
				end
			endcase
		end
	end
	
	
	// 输出结果到下一阶段
	always @ (*) begin
		if(rst == `RstEnable) begin
			aluop_o <= `NOP;
			alufunct3_o <= `NOP_FUNCT3;
			me_o <= `MemDisable;
			maddr_o <= `NopMem;
			wreg_o <= `WriteDisable;
			wd_o <= `NopRegAddr;
			wdata_o <= `ZeroWord;		
		end
		else begin
			aluop_o <= aluop_i;
			alufunct3_o <= alufunct3_i;
			me_o <= me;
			maddr_o <= maddr;
			wreg_o <= wreg_i;
			wd_o <= wd_i;
			wdata_o <= logicout;
		end
	end
	
	// forwarding
	always @ (*) begin 
		if(rst == `RstEnable) begin
			wreg_f <= `WriteDisable;
			wd_f <= `NopRegAddr;
			wdata_f <= `ZeroWord;
		end
		else begin
			if(aluop_i == `LOAD) begin
				wreg_f <= `WriteDisable;
			end			// 数据还没准备好, 不应该forwarding回去
			else begin
				wreg_f <= wreg_o;
			end	
			wd_f <= wd_o;
			wdata_f <= wdata_o;		
		end
	end

endmodule