class fifo_cov #(parameter DEPTH=8);

  virtual fifo_if vif;

  function new(virtual fifo_if vif);
    this.vif = vif;
    
    // Covergroup is its own object, not auto-created just
    // by declaring it in the class, so must construct it here
    cg_fifo = new();
  endfunction

  covergroup cg_fifo; // Sampled explicitly via sample() calls
    option.per_instance = 1;

    cp_state: coverpoint vif.num_occupied {
      bins EMPTY        = {0};
      bins ALMOST_EMPTY  = {1};
      bins MID           = {[2:DEPTH-2]};
      bins ALMOST_FULL   = {DEPTH-1};
      bins FULL          = {DEPTH};
    }

    cp_operation: coverpoint {vif.w_en, vif.r_en} {
      bins NONE       = {2'b00};
      bins WRITE_ONLY = {2'b10};
      bins READ_ONLY  = {2'b01};
      bins BOTH       = {2'b11};
    }

    cx_state_op: cross cp_state, cp_operation {
      bins EMPTY_WRITE      = binsof(cp_state) intersect {0} && binsof(cp_operation) intersect {2'b10};
      bins EMPTY_READ       = binsof(cp_state) intersect {0} && binsof(cp_operation) intersect {2'b01};
      bins EMPTY_BOTH       = binsof(cp_state) intersect {0} && binsof(cp_operation) intersect {2'b11};
      bins FULL_WRITE       = binsof(cp_state) intersect {DEPTH} && binsof(cp_operation) intersect {2'b10};
      bins FULL_READ        = binsof(cp_state) intersect {DEPTH} && binsof(cp_operation) intersect {2'b01};
      bins FULL_BOTH        = binsof(cp_state) intersect {DEPTH} && binsof(cp_operation) intersect {2'b11};
      bins MID_BOTH         = binsof(cp_state) intersect {[2:DEPTH-2]} && binsof(cp_operation) intersect {2'b11};
      bins ALMOST_FULL_WR   = binsof(cp_state) intersect {DEPTH-1} && binsof(cp_operation) intersect {2'b10};
      bins ALMOST_EMPTY_RD  = binsof(cp_state) intersect {1} && binsof(cp_operation) intersect {2'b01};
    }

    cp_w_wrap: coverpoint vif.w_wraps {
      bins wrapped_once = {[1:1]};
      bins wrapped_twice_plus = {[2:$]};
    }

    cp_r_wrap: coverpoint vif.r_wraps {
      bins wrapped_once = {[1:1]};
      bins wrapped_twice_plus = {[2:$]};
    }

    cp_reset_state: coverpoint vif.num_occupied iff (!vif.rst_n) {
      bins reset_while_empty = {0};
      bins reset_while_mid   = {[1:DEPTH-1]};
      bins reset_while_full  = {DEPTH};
    }
  endgroup

  function void sample();
    cg_fifo.sample();
  endfunction

  function void cov_report();
    $display("\n------------------------------------");
    $display("        FIFO COVERAGE SUMMARY        ");
    $display("------------------------------------");
    $display(" FIFO State Coverage     : %0.2f%%", cg_fifo.cp_state.get_coverage());
    $display(" Operation Coverage      : %0.2f%%", cg_fifo.cp_operation.get_coverage());
    $display(" State x Operation Cross : %0.2f%%", cg_fifo.cx_state_op.get_coverage());
    $display(" Write Pointer Wrap      : %0.2f%%", cg_fifo.cp_w_wrap.get_coverage());
    $display(" Read Pointer Wrap       : %0.2f%%", cg_fifo.cp_r_wrap.get_coverage());
    $display(" Reset State Coverage    : %0.2f%%", cg_fifo.cp_reset_state.get_coverage());
    $display("------------------------------------");
    $display(" TOTAL COVERAGE          : %0.2f%%", cg_fifo.get_coverage());
    $display("------------------------------------\n");
  endfunction

endclass