class fifo_chk #(parameter DEPTH=8, parameter DATA_WIDTH=8);
  
  virtual fifo_if vif;
  
  logic [DATA_WIDTH-1:0] exp_q[$];
  
  // Since the checker class drives num_occupied
  // which is a signal from interface, it needs a
  // virtual interface handle
  function new(virtual fifo_if vif);
    this.vif = vif;
  endfunction
  
  function void push_exp (input logic [DATA_WIDTH-1:0] d);
    if (vif.num_occupied < DEPTH) begin 
      exp_q.push_back(d);
      vif.num_occupied++;
    end
    else $warning("OVERFLOW ALERT"); // Debug display
  endfunction
  
  function logic [DATA_WIDTH-1:0] pop_exp();
    if (vif.num_occupied !== 0) begin
      logic [DATA_WIDTH-1:0] d;
      d = exp_q.pop_front();
      vif.num_occupied--;
      return d;
    end
    else begin
      $warning("UNDERFLOW ALERT"); // Debug display
      return null;
    end
  endfunction
  
  function bit compare(logic [DATA_WIDTH-1:0] exp, logic [DATA_WIDTH-1:0] act);
    if (exp !== act) begin
      $error("TIME: %0t | FAILED! EXPECTED: %h, ACTUAL: %h", $time, exp, act);
	  return 0; 
    end
    else begin
      $display("TIME: %0t | SUCCESS! EXPECTED: %h, ACTUAL: %h", $time, exp, act);
      return 1;
    end
  endfunction
  
endclass