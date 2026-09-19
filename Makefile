RTL_DIR = rtl
TB_DIR = tb
TOP_RTL = synchronous_fifo
TOP_TB = sync_fifo_TB

# Automatically find all RTL and testbench source files
RTL_FILES := $(wildcard $(RTL_DIR)/*.v $(RTL_DIR)/*.sv)
TB_FILES  := $(wildcard $(TB_DIR)/*.v $(TB_DIR)/*.sv)

# Common Verilator flags
# -Wno-EOFNEWLINE: disable lint check on mandatory newline after endmodule
# -Wno-DECLFILENAME: disable lint check on filename has to be same as module name
VERILATOR_FLAGS = --Wall \
-Wno-EOFNEWLINE \
-Wno-DECLFILENAME \
-Wno-UNUSEDSIGNAL \
-Wno-UNUSEDPARAM \
-Wno-UNDRIVEN

# Lint rtl only
lint_rtl:
	verilator --lint-only $(VERILATOR_FLAGS) $(RTL_FILES) --top-module $(TOP_RTL)

# Lint both rtl and tb
lint_tb:
	verilator --lint-only $(VERILATOR_FLAGS) $(RTL_FILES) $(TB_FILES) --top-module $(TOP_TB)

# Elaborate/compile only (no simulation)
compile:
	verilator --sv $(VERILATOR_FLAGS) $(RTL_FILES) $(TB_FILES) --top-module $(TOP_TB) --binary -o sim_out

clean:
	rm -rf obj_dir sim_out