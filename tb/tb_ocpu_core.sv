//============================================================================-
// OCPU Core Testbench
// Top-level testbench for OCPU Core verification
//============================================================================-

`timescale 1ns/1ps

module ocpu_core_tb;

    //=========================================================================
    // Clock and Reset
    //=========================================================================
    reg clk;
    reg reset_n;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz
    end
    
    // Reset generation
    initial begin
        reset_n = 0;
        #100 reset_n = 1;
    end
    
    //=========================================================================
    // DUT Signals
    //=========================================================================
    // Instruction memory interface
    wire [63:0] imem_addr;
    wire        imem_req;
    reg  [31:0] imem_rdata;
    reg         imem_ready;
    
    // Data memory interface
    wire [63:0] dmem_addr;
    wire [63:0] dmem_wdata;
    wire [7:0]  dmem_be;
    wire        dmem_req;
    wire        dmem_wr;
    reg  [63:0] dmem_rdata;
    reg         dmem_ready;
    
    // Debug interface
    reg         dbg_en;
    reg  [15:0] dbg_addr;
    reg         dbg_wr;
    reg  [63:0] dbg_wdata;
    wire [63:0] dbg_rdata;
    
    // Interrupts
    reg         irq_timer;
    reg         irq_software;
    reg         irq_external;
    
    //=========================================================================
    // DUT Instantiation
    //=========================================================================
    ocpu_core u_dut (
        .clk(clk),
        .reset_n(reset_n),
        
        // Instruction memory
        .imem_addr(imem_addr),
        .imem_req(imem_req),
        .imem_rdata(imem_rdata),
        .imem_ready(imem_ready),
        
        // Data memory
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_be(dmem_be),
        .dmem_req(dmem_req),
        .dmem_wr(dmem_wr),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        
        // Debug
        .dbg_en(dbg_en),
        .dbg_addr(dbg_addr),
        .dbg_wr(dbg_wr),
        .dbg_wdata(dbg_wdata),
        .dbg_rdata(dbg_rdata),
        
        // Interrupts
        .irq_timer(irq_timer),
        .irq_software(irq_software),
        .irq_external(irq_external)
    );
    
    //=========================================================================
    // Memory Model
    //=========================================================================
    reg [7:0] memory [0:1024*1024-1];  // 1MB memory
    
    // Initialize memory
    initial begin
        integer i;
        for (i = 0; i < 1024*1024; i = i + 1) begin
            memory[i] = 8'h00;
        end
        
        // Load test program
        $readmemh("test_program.hex", memory);
    end
    
    // Instruction memory response
    always @(posedge clk) begin
        if (imem_req) begin
            imem_rdata <= {memory[imem_addr+3], memory[imem_addr+2],
                          memory[imem_addr+1], memory[imem_addr]};
            imem_ready <= 1'b1;
        end else begin
            imem_ready <= 1'b0;
        end
    end
    
    // Data memory response
    always @(posedge clk) begin
        if (dmem_req) begin
            if (dmem_wr) begin
                // Write
                if (dmem_be[0]) memory[dmem_addr]   <= dmem_wdata[7:0];
                if (dmem_be[1]) memory[dmem_addr+1] <= dmem_wdata[15:8];
                if (dmem_be[2]) memory[dmem_addr+2] <= dmem_wdata[23:16];
                if (dmem_be[3]) memory[dmem_addr+3] <= dmem_wdata[31:24];
                if (dmem_be[4]) memory[dmem_addr+4] <= dmem_wdata[39:32];
                if (dmem_be[5]) memory[dmem_addr+5] <= dmem_wdata[47:40];
                if (dmem_be[6]) memory[dmem_addr+6] <= dmem_wdata[55:48];
                if (dmem_be[7]) memory[dmem_addr+7] <= dmem_wdata[63:56];
            end else begin
                // Read
                dmem_rdata <= {memory[dmem_addr+7], memory[dmem_addr+6],
                              memory[dmem_addr+5], memory[dmem_addr+4],
                              memory[dmem_addr+3], memory[dmem_addr+2],
                              memory[dmem_addr+1], memory[dmem_addr]};
            end
            dmem_ready <= 1'b1;
        end else begin
            dmem_ready <= 1'b0;
        end
    end
    
    //=========================================================================
    // Test Sequence
    //=========================================================================
    initial begin
        // Initialize inputs
        dbg_en = 0;
        dbg_addr = 0;
        dbg_wr = 0;
        dbg_wdata = 0;
        irq_timer = 0;
        irq_software = 0;
        irq_external = 0;
        
        // Wait for reset
        @(posedge reset_n);
        #100;
        
        // Run test
        $display("========================================");
        $display("OCPU Core Testbench Started");
        $display("========================================");
        
        // Wait for some cycles
        repeat(1000) @(posedge clk);
        
        $display("========================================");
        $display("Test Complete");
        $display("========================================");
        
        // Dump some statistics
        $display("Final PC: %h", u_dut.pc);
        
        $finish;
    end
    
    //=========================================================================
    // Waveform Dump
    //=========================================================================
    initial begin
        $dumpfile("waves/ocpu_core_tb.vcd");
        $dumpvars(0, ocpu_core_tb);
    end
    
    //=========================================================================
    // Monitor
    //=========================================================================
    //always @(posedge clk) begin
    //    if (imem_req)
    //        $display("[Fetch] PC=%h IR=%h", imem_addr, imem_rdata);
    //end
    
    //=========================================================================
    // Timeout
    //=========================================================================
    initial begin
        #1000000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
