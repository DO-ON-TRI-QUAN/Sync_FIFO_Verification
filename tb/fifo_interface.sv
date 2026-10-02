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
  
  // Independently-tracked occupancy, driven directly off observed
  // w_en/r_en/full/empty. Updates via NBA on
  // the same edge the DUT's own pointers use, so it stays correct
  // automatically for every task, and serves as an independent
  // cross-check against the DUT's full/empty logic.
  logic [$clog2(DEPTH):0] num_occupied;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      num_occupied <= 0;
    else begin
      // Legal write = w_en asserted and FIFO not full
      // Legal read  = r_en asserted and FIFO not empty
      // Simultaneous legal write+read (2'b11) nets to no occupancy change
      case ({w_en && !full, r_en && !empty})
        2'b10:   num_occupied <= num_occupied + 1; // write only
        2'b01:   num_occupied <= num_occupied - 1; // read only
        default: num_occupied <= num_occupied;     // both or neither -> no change
      endcase
    end
  end
  
   // Independent wrap-around counter
  int unsigned w_count, r_count;
  int unsigned w_wraps, r_wraps;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_count <= 0; r_count <= 0;
      w_wraps <= 0; r_wraps <= 0;
    end
    else begin
      if (w_en && !full) begin
        w_count <= w_count + 1;
        if ((w_count + 1) % DEPTH == 0) w_wraps <= w_wraps + 1;
      end
      if (r_en && !empty) begin
        r_count <= r_count + 1;
        if ((r_count + 1) % DEPTH == 0) r_wraps <= r_wraps + 1;
      end
    end
  end
  
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
    (empty && r_en && !w_en) |=> empty; 
  endproperty
      
  assert property (reject_read_empty)
    else $error("READ POINTER MOVED WHEN EMPTY");

  // Reject write when full
  property reject_write_full;
    @(posedge clk) disable iff (!rst_n)
    (full && w_en && !r_en) |=> full; 
  endproperty
      
  assert property (reject_write_full)
    else $error("WRITE POINTER MOVED WHEN FULL");
    
    
endinterface
/*
NOTE:
  num_occupied vs exp_q (checker model) should stay fully
separate, never cross-reference each other:

- exp_q (in fifo_chk)     -> procedural, push/pop driven by tasks,
                             used for data compare (push_exp/pop_exp/compare)
- num_occupied (in fifo_if) -> clocked, driven independently off
                               observed w_en/r_en/full/empty,
                               used by concurrent assertions/coverage

Bug hit: checker push_exp/pop_exp originally guarded against
over/underflow by checking vif.num_occupied. Since num_occupied is
updated by its own always block (same edge the DUT's read/write
commits), by the time pop_exp() ran in a task, num_occupied had
already been decremented for that same read, so the guard saw
"0 occupied" one call too early and wrongly treated a real,
still-pending entry as underflow. Always showed up on the last
pop of a drain, since that's where the off-by-one finally mattered.

Fix: each model only ever checks its own state (exp_q.size()),
never the other's. Two independently-derived models of the same
quantity are fine for this project, even useful as a cross-check, but only if
neither's internal logic depends on reading the other's value.
*/