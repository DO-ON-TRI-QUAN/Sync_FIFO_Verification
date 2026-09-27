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
  
  // Internal signal, keep track of number of occupied slots in the queue
  int num_occupied = 0;
  
  // Clocking block
  clocking cb @(posedge clk);
    default input #1step output #1;
    output data_in, w_en, r_en;
    input data_out, full, empty;
  endclocking
  
  // Assertions list
  // empty flag 
  property empty_flag_assert;
    @(posedge clk) disable iff (!rst_n)
    (num_occupied == 0) |-> empty;
  endproperty
  
  assert property (empty_flag_assert)
    else $error("EMPTY FLAG ISNT ASSERTED WHEN FIFO IS EMPTY");
  
  // full flag 
  property full_flag_assert;
    @(posedge clk) disable iff (!rst_n)
    (num_occupied == DEPTH) |-> full;
  endproperty
  
  assert property (full_flag_assert)
    else $error("FULL FLAG ISNT ASSERTED WHEN FIFO IS FULL");  
    
  // Note for 2 assertions below: Due to the logic of comparing wptr and rptr for full and empty condition, if somehow any of them move when it shouldnt, then the full or empty flag would deassert
    
  // Reject read when empty
  property reject_read_empty;
    @(posedge clk) disable iff (!rst_n)
    (empty && r_en) |=> empty; 
  endproperty
      
  assert property (reject_read_empty)
    else $error("READ POINTER MOVED WHEN EMPTY");

  // Reject write when full
  property reject_write_full;
    @(posedge clk) disable iff (!rst_n)
    (full && w_en) |=> full; 
  endproperty
      
  assert property (reject_write_full)
    else $error("WRITE POINTER MOVED WHEN FULL");
    
    
endinterface
  