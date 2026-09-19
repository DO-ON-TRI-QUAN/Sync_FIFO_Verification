`timescale 1ns/1ps

module sync_fifo_TB;
  parameter DEPTH = 8;
  parameter DATA_WIDTH = 8;
  
  // Local variables of tb top, to supply/drive the input ports of interface and DUT's clk, rst_n
  bit clk, rst_n;
  
  // Queue to push data_in and pop data_out (for checker)
  reg [DATA_WIDTH-1:0] data_q[$];
  
  // Store popped data from queue for comparing
  reg [DATA_WIDTH-1:0] data;
  
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
    
    if_inst.w_en <= 0; 
    if_inst.r_en <= 0;
    if_inst.data_in <= 0;

    
    @(posedge clk) 
    #1
    rst_n = 1;
    
    @(posedge clk) 
    #1
    if_inst.w_en <= 1;
    if_inst.r_en <= 0;
    if_inst.data_in <= DATA_WIDTH'($urandom);
    #1
    data_q.push_back(if_inst.data_in);

    @(posedge clk) 
    #1
    if_inst.w_en <= 0;
    if_inst.r_en <= 1; 
    
    @(posedge clk) 
    #1 
    data = data_q.pop_front();
    if (if_inst.data_out !== data)
      $error("TIME = %0t: Comparison failed, expected data = %h, actual data_out = %h", $time, data, if_inst.data_out);
    else
      $display("TIME = %0t: Comparison passed, expected data = %h, actual data_out = %h", $time, data, if_inst.data_out);
    
    repeat(12) begin
      @(posedge clk) 
      #1
      if_inst.w_en <= 1;
      if_inst.r_en <= 0;
      if_inst.data_in <= DATA_WIDTH'($urandom);
    end  
    
    repeat(12) begin
      #1
      @(posedge clk) 
      if_inst.w_en <= 0;
      if_inst.r_en <= 1;
      if_inst.data_in <= DATA_WIDTH'($urandom);
    end    

    #30
    $finish;
  end

  initial begin 
    $dumpfile("dump.vcd"); 
    $dumpvars;
  end


endmodule
