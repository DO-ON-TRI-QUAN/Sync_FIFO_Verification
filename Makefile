RTL_DIR = rtl
TB_DIR = tb
TOP = synchronous_fifo

RTL_FILES = $(RTL_DIR)/fifo.v

# -Wno-EOFNEWLINE: disable lint check on mandatory newline after endmodule
# -Wno-DECLFILENAME: disable lint check on filename has to be same as module name

# Lint only
lint:
	verilator --lint-only --Wall -Wno-EOFNEWLINE -Wno-DECLFILENAME $(RTL_FILES) --top-module $(TOP)

# Elaborate/compile only (no simulation)
compile:
	verilator --sv --Wall -Wno-EOFNEWLINE -Wno-DECLFILENAME $(RTL_FILES) --top-module $(TOP) --binary -o sim_out

clean:
	rm -rf obj_dir sim_out