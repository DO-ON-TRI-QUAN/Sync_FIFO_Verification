interface fifo_if #(
  parameter DEPTH=8,
  parameter DATA_WIDTH=8
)(
  input logic clk,
  input logic rst_n
);
  
  logic [DATA_WIDTH-1:0] data_in;
  logic [DATA_WIDTH-1:0] data_out;
  logic w_en, r_en;
  logic full, empty;
  
  clocking cb @(posedge clk);
    default input #1step output #1;
    output data_in, w_en, r_en;
    input data_out, full, empty;
  endclocking
  
endinterface
  