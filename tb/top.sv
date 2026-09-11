`timescale 1ns/1ps

module sync_fifo_TB;
  parameter DEPTH = 8;
  parameter DATA_WIDTH = 8;
  
  reg clk, rst_n;
  reg w_en, r_en;
  reg [DATA_WIDTH-1:0] data_in;

  wire [DATA_WIDTH-1:0] data_out;
  wire full, empty;
  
  // Queue to push data_in
  // reg [DATA_WIDTH-1:0] wdata_q[$], wdata;

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
    rst_n = 1;
    w_en = 0; 
    r_en = 0;
    data_in = 0;
  end
  
  initial begin 
    $dumpfile("dump.vcd"); $dumpvars;
  end


endmodule
