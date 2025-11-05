// alu.v
`timescale 1ns/1ps

module alu (
    input  [31:0] a,
    input  [31:0] b,
    input  [1:0]  alu_control, // 00 ADD, 01 AND, 11 SUB
    output reg [31:0] result,
    output zero
);
    always @(*) begin
        case (alu_control)
            2'b01: result = a & b;    // AND
            2'b11: result = a - b;    // SUB
            default: result = a + b;  // ADD
        endcase
    end
    assign zero = (result == 32'b0);
endmodule

//register_file.v
`timescale 1ns/1ps
module register_file (
    input clk,
    input reg_write,
    input [4:0] rs, rt, rd,
    input [31:0] write_data,
    output reg [31:0] rs_data, rt_data
);
    reg [31:0] registers [0:31];
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] = 32'h0;
        registers[1] = 32'h0000000A;
        registers[2] = 32'h00000003;
        registers[5] = 32'h0000000F;
    end
    always @(*) begin
        rs_data = registers[rs];
        rt_data = registers[rt];
    end
    always @(posedge clk) begin
        if (reg_write && rd != 0)
            registers[rd] <= write_data;
    end
endmodule

//instruction_memory.v
`timescale 1ns/1ps
module instruction_memory (
    input  [31:0] addr,
    output [31:0] instr_out
);
    reg [31:0] instr_mem [0:255];
    integer i;
    initial begin
        instr_mem[0] = 32'h20010005; 
        instr_mem[1] = 32'h20020007; 
        instr_mem[2] = 32'h00221820; 
        instr_mem[3] = 32'h00622022; 
        instr_mem[4] = 32'h00822824; 
        instr_mem[5] = 32'hAC030000; 
        instr_mem[6] = 32'h8C060000; 
        instr_mem[7] = 32'h10C30001; 
        instr_mem[8] = 32'h20070099; 
        instr_mem[9] = 32'h200800AA; 
        for (i = 10; i < 256; i = i + 1)
            instr_mem[i] = 32'h00000000;
    end
    assign instr_out = instr_mem[addr[9:2]];
endmodule

//data_memory.v
`timescale 1ns/1ps
module data_memory (
    input clk,
    input mem_write,
    input mem_read,
    input [31:0] addr,
    input [31:0] write_data,
    output reg [31:0] read_data
);
    reg [31:0] mem [0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'hDEADBEEF + i;
        read_data = 32'b0;
    end
    always @(posedge clk) begin
        if (mem_write)
            mem[addr[9:2]] <= write_data;
        if (mem_read)
            read_data <= mem[addr[9:2]];
    end
endmodule

//control_unit.v
`timescale 1ns/1ps
module control_unit (
    input  [5:0] opcode,
    input  [5:0] funct,
    output reg   RegDst,
    output reg   ALUSrc,
    output reg   MemtoReg,
    output reg   RegWrite,
    output reg   MemRead,
    output reg   MemWrite,
    output reg   Branch,
    output reg [1:0] ALUControl
);
    always @(*) begin
        RegDst=0;ALUSrc=0;MemtoReg=0;RegWrite=0;MemRead=0;MemWrite=0;Branch=0;
        ALUControl=2'b00;
        case (opcode)
            6'b000000: begin
                RegDst=1;RegWrite=1;ALUSrc=0;
                case (funct)
                    6'b100000: ALUControl=2'b00;
                    6'b100010: ALUControl=2'b11;
                    6'b100100: ALUControl=2'b01;
                endcase
            end
            6'b100011: begin
                RegDst=0;ALUSrc=1;MemtoReg=1;RegWrite=1;MemRead=1;ALUControl=2'b00;
            end
            6'b101011: begin
                ALUSrc=1;MemWrite=1;ALUControl=2'b00;
            end
            6'b000100: begin
                Branch=1;ALUControl=2'b11;
            end
            6'b001000: begin
                RegDst=0;ALUSrc=1;RegWrite=1;ALUControl=2'b00;
            end
        endcase
    end
endmodule

// program_counter.v
`timescale 1ns/1ps
module program_counter (
    input clk, input reset,
    input [31:0] pc_in,
    output reg [31:0] pc_out
);
    always @(posedge clk or posedge reset)
        if (reset) pc_out <= 0;
        else pc_out <= pc_in;
endmodule

//mips_cpu.v (top-level)
`timescale 1ns/1ps
module mips_cpu (
    input clk, input reset,
    output [31:0] pc, instr, alu_result, mem_read_data
);
    wire [31:0] pc_next, pc_plus4;
    wire [5:0] opcode = instr[31:26];
    wire [4:0] rs = instr[25:21], rt = instr[20:16], rd = instr[15:11];
    wire [15:0] imm = instr[15:0];
    wire [5:0] funct = instr[5:0];
    wire [31:0] rs_data, rt_data, alu_b;
    wire alu_zero;
    wire [1:0] alu_control;
    wire RegDst, ALUSrc, MemtoReg, RegWrite, MemRead, MemWrite, Branch;
    wire [31:0] sign_ext_imm = {{16{imm[15]}}, imm};
    wire [31:0] imm_shifted = {sign_ext_imm[29:0], 2'b00};
    wire [31:0] branch_target = pc_plus4 + imm_shifted;
    wire [4:0] write_reg = (RegDst) ? rd : rt;
    wire [31:0] write_back_data = (MemtoReg) ? mem_read_data : alu_result;

    program_counter pc_reg (.clk(clk), .reset(reset), .pc_in(pc_next), .pc_out(pc));
    instruction_memory imem (.addr(pc), .instr_out(instr));
    assign pc_plus4 = pc + 4;
    control_unit ctrl (.opcode(opcode), .funct(funct), .RegDst(RegDst),
                       .ALUSrc(ALUSrc), .MemtoReg(MemtoReg), .RegWrite(RegWrite),
                       .MemRead(MemRead), .MemWrite(MemWrite), .Branch(Branch),
                       .ALUControl(alu_control));
    register_file regs (.clk(clk), .reg_write(RegWrite), .rs(rs), .rt(rt),
                        .rd(write_reg), .write_data(write_back_data),
                        .rs_data(rs_data), .rt_data(rt_data));
    assign alu_b = (ALUSrc) ? sign_ext_imm : rt_data;
    alu the_alu (.a(rs_data), .b(alu_b), .alu_control(alu_control),
                 .result(alu_result), .zero(alu_zero));
    data_memory dmem (.clk(clk), .mem_write(MemWrite), .mem_read(MemRead),
                      .addr(alu_result), .write_data(rt_data),
                      .read_data(mem_read_data));
    wire take_branch = Branch & alu_zero;
    assign pc_next = take_branch ? branch_target : pc_plus4;
endmodule 
