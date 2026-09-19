`timescale 1ns/1ps

module sync_fifo_TB;
  parameter DEPTH = 8;
  parameter DATA_WIDTH = 8;
  
  // Local variables of tb top, to supply/drive the input ports of interface and DUT's clk, rst_n
  bit clk, rst_n;
  
  // Input data 
  logic [DATA_WIDTH-1:0] d;
  
  // Queue to push data_in (for checker)
  reg [DATA_WIDTH-1:0] exp_q[$];
  
  // Store popped data from queue for comparing
  reg [DATA_WIDTH-1:0] exp;
  
  // Interface instantiate
  fifo_if if_inst (
    .clk   (clk),
    .rst_n (rst_n)
  );
  
  // DUT instantiate
  synchronous_fifo #(
    .DEPTH      (DEPTH),
    .DATA_WIDTH (DATA_WIDTH)
  ) DUT (
    .clk       (clk),
    .rst_n     (rst_n),
    
    .data_in   (if_inst.data_in),
    .data_out  (if_inst.data_out),
    .w_en      (if_inst.w_en),
    .r_en 	   (if_inst.r_en),
    .full 	   (if_inst.full),
    .empty 	   (if_inst.empty)
  );

  // Clock
  always #5ns clk = ~clk;

  initial begin
    clk = 0;
    rst_n = 0;
    
    if_inst.cb.w_en <= 0; 
    if_inst.cb.r_en <= 0;
    if_inst.cb.data_in <= 0;

    
    @(if_inst.cb) 
    rst_n = 1;
    
    @(if_inst.cb) 
    d = DATA_WIDTH'($urandom);
    
    if_inst.cb.w_en <= 1;
    if_inst.cb.r_en <= 0;
    if_inst.cb.data_in <= d;
    
    exp_q.push_back(d);

    @(if_inst.cb) 
    if_inst.cb.w_en <= 0;
    if_inst.cb.r_en <= 1; 
    
    @(if_inst.cb) // DUT sees r_en=1 on this edge, data_out updates right after it
    if_inst.cb.r_en <= 0; 
    @(if_inst.cb) // TB samples data_out from just before this edge, so it sees the new value
    exp = exp_q.pop_front();
    if (if_inst.cb.data_out !== exp)
      $error("TIME = %0t: Comparison failed, expected data = %h, actual data_out = %h", $time, exp, if_inst.cb.data_out);
    else
      $display("TIME = %0t: Comparison passed, expected data = %h, actual data_out = %h", $time, exp, if_inst.cb.data_out);
    
    repeat(12) begin
      @(if_inst.cb) 
      
      d = DATA_WIDTH'($urandom);
      
      if_inst.cb.w_en <= 1;
      if_inst.cb.r_en <= 0;
      if_inst.cb.data_in <= d;
    end  
    
    repeat(12) begin
      @(if_inst.cb) 
      d = DATA_WIDTH'($urandom);
      
      if_inst.cb.w_en <= 0;
      if_inst.cb.r_en <= 1;
      if_inst.cb.data_in <= d;
    end    

    #30
    $finish;
  end

  initial begin 
    $dumpfile("dump.vcd"); 
    $dumpvars;
  end


endmodule
