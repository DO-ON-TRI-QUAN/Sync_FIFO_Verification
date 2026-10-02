class fifo_chk #(parameter DEPTH=8, parameter DATA_WIDTH=8);
    
  logic [DATA_WIDTH-1:0] exp_q[$];
  
  function void push_exp (input logic [DATA_WIDTH-1:0] d);
    if (exp_q.size() < DEPTH) begin 
      exp_q.push_back(d);
    end
    else $warning("OVERFLOW ALERT"); // Debug display
  endfunction
  
  function logic [DATA_WIDTH-1:0] pop_exp();
    if (exp_q.size() !== 0) begin
      logic [DATA_WIDTH-1:0] d;
      d = exp_q.pop_front();
      return d;
    end
    else begin
      $warning("UNDERFLOW ALERT"); // Debug display
      return 'x;
    end
  endfunction
  
  function void compare(logic [DATA_WIDTH-1:0] exp, logic [DATA_WIDTH-1:0] act, string tag = "");
    if (exp !== act) begin
      $error("[%s] TIME: %0t | FAILED! EXPECTED: %h, ACTUAL: %h", tag, $time, exp, act);
    end
    else begin
      $display("[%s] TIME: %0t | SUCCESS! EXPECTED: %h, ACTUAL: %h", tag, $time, exp, act);
    end
  endfunction
  
  // Utility function to print out checker queue content
  function void print_state();
    $display("TIME: %0t | exp_q contents: %p", $time, exp_q);
  endfunction
  
endclass