`timescale 1ns/1ps

module sync_fifo_TB;
  parameter DEPTH = 8;
  parameter DATA_WIDTH = 8;
  
  reg clk, rst_n;
  reg w_en, r_en;
  reg [DATA_WIDTH-1:0] data_in;

  wire [DATA_WIDTH-1:0] data_out;
  wire full, empty;
  
  // Queue to push data_in and pop data_out (for checker)
  reg [DATA_WIDTH-1:0] data_q[$];
  
  // Store popped data from queue for comparing
  reg [DATA_WIDTH-1:0] data;

  // Instantiate DUT
  synchronous_fifo #(
    .DEPTH(DEPTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .w_en(w_en),
    .r_en(r_en),
    .data_in(data_in),
    .data_out(data_out),
    .full(full),
    .empty(empty)
  );

  // Clock
  always #5ns clk = ~clk;

  initial begin
    clk = 0;
    rst_n = 0;
    w_en = 0; 
    r_en = 0;
    data_in = 0;

    
    @(posedge clk) 
    #1
    rst_n = 1;
    
    @(posedge clk) 
    #1
    w_en = 1;
    r_en = 0;
    data_in = DATA_WIDTH'($urandom);
    data_q.push_back(data_in);

    @(posedge clk) 
    #1
    w_en = 0;
    r_en = 1; 
    
    @(posedge clk) 
    #1 
    data = data_q.pop_front();
    if (data_out !== data)
      $error("TIME = %0t: Comparison failed, expected data = %h, actual data_out = %h", $time, data, data_out);
    else
      $display("TIME = %0t: Comparison passed, expected data = %h, actual data_out = %h", $time, data, data_out);
    
    repeat(12) begin
      @(posedge clk) 
      #1
      w_en = 1;
      r_en = 0;
      data_in = DATA_WIDTH'($urandom);
    end  
    
    repeat(12) begin
      #1
      @(posedge clk) 
      w_en = 0;
      r_en = 1;
      data_in = DATA_WIDTH'($urandom);
    end    

    #30
    $finish;
  end

  initial begin 
    $dumpfile("dump.vcd"); 
    $dumpvars;
  end


endmodule
