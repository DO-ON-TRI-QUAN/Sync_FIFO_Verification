`timescale 1ns/1ps

module sync_fifo_TB;
  parameter DEPTH = 8;
  parameter DATA_WIDTH = 8;
  
  // Local variables of tb top, to supply/drive the input ports of interface and DUT's clk, rst_n
  bit clk, rst_n;
  
  // Input data to feed into DUT and queue (checker model)
  logic [DATA_WIDTH-1:0] d;
  
  // Data from queue
  logic [DATA_WIDTH-1:0] exp;

  // Interface instantiate
  fifo_if #(
    .DEPTH      (DEPTH), 
    .DATA_WIDTH (DATA_WIDTH)
  ) if_inst (
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
  
  // Checker class handle
  fifo_chk #(
    .DEPTH      (DEPTH),
    .DATA_WIDTH (DATA_WIDTH)
  ) chk;
  
  // Coverage class handle
  fifo_cov #(.DEPTH (DEPTH)) cov;

  // Clock
  always #5ns clk = ~clk;
  
  // Utility tasks
  task automatic do_reset();
    rst_n = 0;
    
    chk.exp_q.delete();
    
    @(if_inst.cb);     
    cov.sample(); 
    rst_n = 1;
    
    @(if_inst.cb);      
  endtask
  
  // Notes: because this project doesnt have a Monitor component,
  // manually sync-ing with the checker model (queue) is needed
  // so num_occupied is correctly updated for assertions and such
  task automatic do_write(logic [DATA_WIDTH-1:0] data);
    @(if_inst.cb);
    if_inst.cb.w_en    <= 1;
    if_inst.cb.r_en    <= 0;
    if_inst.cb.data_in <= data;
    
    @(if_inst.cb);
    cov.sample(); 
    if_inst.cb.w_en <= 0;
    
    @(if_inst.cb);
    chk.push_exp(data);
  endtask

  task automatic do_read(string tag);   
    string t = tag;
    
    @(if_inst.cb);
    if_inst.cb.r_en <= 1;
    if_inst.cb.w_en <= 0;
    
    @(if_inst.cb);
    cov.sample(); 
    if_inst.cb.r_en <= 0;
    
    @(if_inst.cb); // Extra wait so cb.data_out reflects the committed read
    exp = chk.pop_exp();
    chk.compare(exp, if_inst.cb.data_out, t);
  endtask
  
  ////////
  
  // Tasks (based on vplan testcases)
  // For the simplicity of this project, each task is seen as isolated
  
  // TC_RESET_01
  task automatic TC_RESET_01();
    do_reset(); // do_reset() is the same as this testcase
    
    assert(if_inst.cb.empty == 1) else $error("[TC_RESET_01] EMPTY NOT ASSERTED AFTER RESET");
    assert(if_inst.cb.full == 0) else $error(" [TC_RESET_01] FULL INCORRECTLY ASSERTED AFTER RESET");
  endtask
  
  // TC_RESET_02
  task automatic TC_RESET_02();
    do_reset();
    
    repeat (2) begin
      do_write(DATA_WIDTH'($urandom));
      
      @(if_inst.cb)
      assert(if_inst.cb.empty == 0) 
        else $error("[TC_RESET_02] EMPTY ASSERTED AFTER A WRITE");
    end
    
    @(if_inst.cb)
    do_reset();
    
    do_write(DATA_WIDTH'($urandom));
  endtask
  
  // TC_WR_01
  task automatic TC_WR_01();
    do_reset();
    do_write(DATA_WIDTH'($urandom));

    @(if_inst.cb);
    assert(if_inst.cb.empty == 0) else $error("[TC_WR_01] EMPTY STILL ASSERTED AFTER WRITE");
    assert(if_inst.cb.full  == 0) else $error("[TC_WR_01] FULL INCORRECTLY ASSERTED AFTER 1 WRITE");
  endtask

  // TC_WR_02
  task automatic TC_WR_02();
    // Fill completely tp prove the write pointer advanced through slot 7
    // and wrapped back to 0 (full can only assert if the wrap happened).
    do_reset();
    repeat (DEPTH) do_write(DATA_WIDTH'($urandom));

    @(if_inst.cb);
    assert(if_inst.cb.full == 1) else $error("[TC_WR_02] FULL NOT ASSERTED AFTER DEPTH WRITES");

    // Drain and confirm data order intact through the wrap.
    repeat (DEPTH) do_read("TC_WR_02");
  endtask

  // TC_WR_03
  task automatic TC_WR_03();
    do_reset();
    repeat (DEPTH) do_write(DATA_WIDTH'($urandom));

    // Illegal write attempt, shouldnt call push_exp
    @(if_inst.cb);
    if_inst.cb.w_en    <= 1;
    if_inst.cb.r_en    <= 0;
    if_inst.cb.data_in <= DATA_WIDTH'($urandom);
    @(if_inst.cb);
    if_inst.cb.w_en <= 0;

    @(if_inst.cb);
    assert(if_inst.cb.full == 1) else $error("[TC_WR_03] FULL DEASSERTED AFTER ILLEGAL WRITE");
    cov.sample(); 

    // Drain all 8 and confirm only the legal written data returns.
    repeat (DEPTH) do_read("TC_WR_03");
  endtask

  // TC_RD_01
  task automatic TC_RD_01();
    do_reset();
    do_write(DATA_WIDTH'($urandom));
    do_read("TC_RD_01"); // Comparison happens inside

    @(if_inst.cb);
    assert(if_inst.cb.empty == 1) else $error("[TC_RD_01] EMPTY NOT ASSERTED AFTER DRAINING ONLY ENTRY");
  endtask

  // TC_RD_02
  task automatic TC_RD_02();
    // Fill and fully drain -> read pointer wraps slot 7 -> 0.
    do_reset();
    repeat (DEPTH) do_write(DATA_WIDTH'($urandom));
    repeat (DEPTH) do_read("TC_RD_02");

    @(if_inst.cb);
    assert(if_inst.cb.empty == 1) else $error("[TC_RD_02] EMPTY NOT ASSERTED AFTER FULL DRAIN");
  endtask

  // TC_RD_03
  task automatic TC_RD_03();
    do_reset();

    // Illegal read attempt, shouldnt call pop_exp.
    @(if_inst.cb);
    if_inst.cb.r_en <= 1;
    if_inst.cb.w_en <= 0;
    @(if_inst.cb);
    if_inst.cb.r_en <= 0;

    @(if_inst.cb);
    assert(if_inst.cb.empty == 1) else $error("[TC_RD_03] EMPTY DEASSERTED AFTER ILLEGAL READ");
    cov.sample(); 
  endtask

  // TC_FLAG_01
  task automatic TC_FLAG_01();
    do_reset();
    @(if_inst.cb);
    assert(if_inst.cb.empty == 1) else $error("[TC_FLAG_01] EMPTY NOT ASSERTED IMMEDIATELY AFTER RESET");
  endtask

  // TC_FLAG_02
  task automatic TC_FLAG_02();
    do_reset();
    do_write(DATA_WIDTH'($urandom));
    @(if_inst.cb);
    assert(if_inst.cb.empty == 0) else $error("[TC_FLAG_02] EMPTY DID NOT DEASSERT AFTER FIRST WRITE");
  endtask

  // TC_FLAG_03
  task automatic TC_FLAG_03();
    do_reset();
    repeat (DEPTH-1) do_write(DATA_WIDTH'($urandom));
    @(if_inst.cb);
    assert(if_inst.cb.full == 0) else $error("[TC_FLAG_03] FULL ASSERTED EARLY BEFORE DEPTH WRITES");

    do_write(DATA_WIDTH'($urandom)); // 8th write
    @(if_inst.cb);
    assert(if_inst.cb.full == 1) else $error("FULL NOT ASSERTED AFTER EXACTLY DEPTH WRITES");
  endtask

  // TC_FLAG_04
  task automatic TC_FLAG_04();
    do_reset();
    repeat (DEPTH) do_write(DATA_WIDTH'($urandom));
    do_read("TC_FLAG_04");
    @(if_inst.cb);
    assert(if_inst.cb.full == 0) else $error("[TC_FLAG_04] FULL DID NOT DEASSERT AFTER SINGLE READ FROM FULL");
  endtask

  // TC_FLAG_05
  task automatic TC_FLAG_05();
    do_reset();
    repeat (DEPTH-1) begin
      do_write(DATA_WIDTH'($urandom));
      @(if_inst.cb);
      assert(if_inst.cb.full == 0) else $error("[TC_FLAG_05] FULL INCORRECTLY ASSERTED MID-FILL");
    end
    do_write(DATA_WIDTH'($urandom)); // Now full

    repeat (DEPTH-1) begin
      do_read("TC_FLAG_05");
      @(if_inst.cb);
      assert(if_inst.cb.empty == 0) else $error("[TC_FLAG_05] EMPTY INCORRECTLY ASSERTED MID-DRAIN");
    end
    do_read("TC_FLAG_05"); // Now empty
  endtask

  // TC_DATA_01
  task automatic TC_DATA_01();
    int n;
    n = 5; // Mid-DEPTH
    do_reset();
    repeat (n) do_write(DATA_WIDTH'($urandom));
    repeat (n) do_read("TC_DATA_01"); // compare() inside catches any order/value mismatch
  endtask

  // TC_DATA_02
  task automatic TC_DATA_02();
    do_reset();
    do_write(DATA_WIDTH'($urandom));
    do_write(DATA_WIDTH'($urandom));
    do_read("TC_DATA_02");
    do_write(DATA_WIDTH'($urandom));
    do_read("TC_DATA_02");
    do_read("TC_DATA_02");
    do_write(DATA_WIDTH'($urandom));
    do_read("TC_DATA_02");
  endtask

  // TC_SIMUL_01
  task automatic TC_SIMUL_01();
    // Neither full nor empty, both should occur.
    do_reset();
    repeat (3) do_write(DATA_WIDTH'($urandom)); // mid-fill, not full/empty

    d = DATA_WIDTH'($urandom);
    @(if_inst.cb);
    if_inst.cb.w_en    <= 1;
    if_inst.cb.r_en    <= 1;
    if_inst.cb.data_in <= d;
    @(if_inst.cb);
    
    cov.sample(); 
    
    if_inst.cb.w_en <= 0;
    if_inst.cb.r_en <= 0;
    chk.push_exp(d);
    @(if_inst.cb);
    exp = chk.pop_exp();
    chk.compare(exp, if_inst.cb.data_out, "TC_SIMUL_01");
    
  endtask

  // TC_SIMUL_02
  task automatic TC_SIMUL_02();
    // Empty: write should occur, read should not.
    do_reset();

    d = DATA_WIDTH'($urandom);
    @(if_inst.cb);
    if_inst.cb.w_en    <= 1;
    if_inst.cb.r_en    <= 1;
    if_inst.cb.data_in <= d;
    @(if_inst.cb);
    
    cov.sample(); 
    
    if_inst.cb.w_en <= 0;
    if_inst.cb.r_en <= 0;
    chk.push_exp(d); // Only push since read was illegal, nothing to pop

    @(if_inst.cb);
    assert(if_inst.cb.empty == 0) else $error("[TC_SIMUL_02] EMPTY DID NOT DEASSERT, WRITE DID NOT OCCUR DURING SIMUL AT EMPTY");
  endtask

  // TC_SIMUL_03
  task automatic TC_SIMUL_03();
    // Full, read should occur, write should not.
    do_reset();
    repeat (DEPTH) do_write(DATA_WIDTH'($urandom));

    @(if_inst.cb);
    if_inst.cb.w_en    <= 1;
    if_inst.cb.r_en    <= 1;
    if_inst.cb.data_in <= DATA_WIDTH'($urandom);
    @(if_inst.cb);
    
    cov.sample(); 
    
    if_inst.cb.w_en <= 0;
    if_inst.cb.r_en <= 0;
    @(if_inst.cb);
    exp = chk.pop_exp(); // Only pop since write was illegal, nothing tp push
    chk.compare(exp, if_inst.cb.data_out, "TC_SIMUL_03");
    
    assert(if_inst.cb.full == 0) else $error("[TC_SIMUL_03] FULL DID NOT DEASSERT, READ DID NOT OCCUR DURING SIMUL AT FULL");
  endtask

  // TC_SIMUL_04
  task automatic TC_SIMUL_04();
    // Hover near empty boundary with back-to-back simultaneous operations.
    do_reset();
    do_write(DATA_WIDTH'($urandom)); // 1 entry, avoids starting at empty

    repeat (6) begin
      d = DATA_WIDTH'($urandom);
      @(if_inst.cb);
      if_inst.cb.w_en    <= 1;
      if_inst.cb.r_en    <= 1;
      if_inst.cb.data_in <= d;
      
      @(if_inst.cb);
      
      cov.sample(); 

      if_inst.cb.w_en <= 0;
      if_inst.cb.r_en <= 0;
      
      @(if_inst.cb);
      chk.push_exp(d);
      exp = chk.pop_exp();
      chk.compare(exp, if_inst.cb.data_out, "TC_SIMUL_04");
      
    end
  endtask

  // TC_FULL_TRAVERSAL_01
  task automatic TC_FULL_TRAVERSAL_01();
    int cycle;
    do_reset();
    
    for (cycle = 0; cycle < 3; cycle++) begin
      repeat (DEPTH) do_write(DATA_WIDTH'($urandom));
      @(if_inst.cb);
      assert(if_inst.cb.full == 1) else $error("[TC_FULL_TRAVERSAL_01] FULL NOT ASSERTED ON FILL CYCLE %0d", cycle);

      repeat (DEPTH) do_read("TC_FULL_TRAVERSAL_01");
      @(if_inst.cb);
      assert(if_inst.cb.empty == 1) else $error("[TC_FULL_TRAVERSAL_01] EMPTY NOT ASSERTED ON DRAIN CYCLE %0d", cycle);
    end
  endtask

  // TC_BOUNDARY_01
  task automatic TC_BOUNDARY_01();
    // Offset the pointers first so the full condition will land
    // on a non-zero index, not just the trivial 0-start case.
    do_reset();
    repeat (3) do_write(DATA_WIDTH'($urandom));
    repeat (3) do_read("TC_BOUNDARY_01");

    repeat (DEPTH) do_write(DATA_WIDTH'($urandom));
    @(if_inst.cb);
    assert(if_inst.cb.full == 1) else $error("[TC_BOUNDARY_01] FULL NOT ASSERTED AT OFFSET BOUNDARY CASE");
  endtask
  
  ////////

  initial begin
    // Instantiate the checker
    chk = new();
    cov = new(if_inst);
    
    TC_RESET_01();
    TC_RESET_02();
    
    TC_WR_01();
    TC_WR_02();
    TC_WR_03();
    
    TC_RD_01();
    TC_RD_02();
    TC_RD_03();
    
    TC_FLAG_01();
    TC_FLAG_02();
    TC_FLAG_03();
    TC_FLAG_04();
    TC_FLAG_05();
    
    TC_DATA_01();
    TC_DATA_02();
    
    TC_SIMUL_01();
    TC_SIMUL_02();
    TC_SIMUL_03();
    TC_SIMUL_04();
    
    TC_FULL_TRAVERSAL_01();
    TC_BOUNDARY_01();
    
    #10
    
    cov.cov_report();

    #30
    $finish;
  end

  initial begin 
    $dumpfile("dump.vcd"); 
    $dumpvars;
  end


endmodule
