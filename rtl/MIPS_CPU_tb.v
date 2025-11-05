`timescale 1ns/1ps

module mips_cpu_tb;
    reg clk;
    reg reset;
    wire [31:0] pc, instr, alu_result, mem_read_data;

    mips_cpu uut (
        .clk(clk),
        .reset(reset),
        .pc(pc),
        .instr(instr),
        .alu_result(alu_result),
        .mem_read_data(mem_read_data)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Simulation control
    initial begin
        $dumpfile("mips_cpu_tb.vcd");
        $dumpvars(0, mips_cpu_tb);
        reset = 1; #15; reset = 0;
        $display(">> CPU running...");
        $display("Simulation finished.");
        show_registers;
        show_data_memory;
        $finish;
    end

    task show_registers;
        integer i;
        begin
            for (i=0; i<10; i=i+1)
                $display("R[%0d] = %h", i, uut.regs.registers[i]);
        end
    endtask

    task show_data_memory;
        integer j;
        begin
            for (j=0; j<10; j=j+1)
                $display("MEM[%0d] = %h", j, uut.dmem.mem[j]);
        end
    endtask

endmodule
