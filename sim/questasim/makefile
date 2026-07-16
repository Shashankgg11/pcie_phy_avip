# ============================================================
# Questasim makefile — pcie_phy_avip
# Auto-generated — compiles + elaborates + simulates the AVIP
# standalone using the UVM library shipped with Questasim.
# ============================================================

# --- Tool / library setup ------------------------------------
VSIM         ?= vsim
VLOG         ?= vlog
VLIB         ?= vlib
VMAP         ?= vmap
VOPT         ?= vopt

WORK_LIB     := work
COMPILE_FILE := ../pcie_phy_compile.f
TOP_MODULES  := hdl_top hvl_top
OPT_DESIGN   := pcie_phy_opt

# Default test used by `make simulate` / `make run` — this is the only
# test guaranteed to run standalone with no sequences required.
TESTNAME     ?= pcie_phy_smoke_test

# Questasim ships its own UVM-1.2 — no external +incdir/-L needed
# unless you want to point at a different UVM version; override
# UVM_HOME on the command line to add one, e.g.:
#   make compile UVM_HOME=/path/to/uvm-1.2
UVM_ARGS     :=
ifneq ($(UVM_HOME),)
  UVM_ARGS   := +incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm_pkg.sv -y $(UVM_HOME)/src
endif

VLOG_FLAGS   := -sv -timescale=1ns/1ps +acc -mfcu -f $(COMPILE_FILE) $(UVM_ARGS)
VOPT_FLAGS   := +acc -o $(OPT_DESIGN)
VSIM_FLAGS   := -c -do "run -all; quit -f"

.PHONY: all compile elaborate simulate run clean help

all: run

# --- 1. Compile -----------------------------------------------
compile:
	@echo "==> [compile] creating work library"
	$(VLIB) $(WORK_LIB)
	$(VMAP) work $(WORK_LIB)
	@echo "==> [compile] compiling $(COMPILE_FILE)"
	$(VLOG) $(VLOG_FLAGS)

# --- 2. Elaborate ------------------------------------------------
elaborate: compile
	@echo "==> [elaborate] optimizing $(TOP_MODULES)"
	$(VOPT) $(TOP_MODULES) $(VOPT_FLAGS)

# --- 3. Simulate (single test, batch mode) ------------------------
simulate:
	@echo "==> [simulate] running +UVM_TESTNAME=$(TESTNAME)"
	$(VSIM) $(OPT_DESIGN) +UVM_TESTNAME=$(TESTNAME) $(VSIM_FLAGS)

# --- compile + elaborate + simulate in one shot ---------------------
run: elaborate simulate

# --- housekeeping ------------------------------------------------------
clean:
	@echo "==> [clean] removing work library / logs / waves"
	rm -rf $(WORK_LIB) $(OPT_DESIGN) transcript vsim.wlf *.log *.vstf

help:
	@echo "Targets:"
	@echo "  make compile              - compile all RTL/UVM sources (vlib/vmap/vlog)"
	@echo "  make elaborate            - compile + vopt into $(OPT_DESIGN)"
	@echo "  make simulate             - run $(OPT_DESIGN) with +UVM_TESTNAME=$(TESTNAME)"
	@echo "  make run                  - elaborate + simulate (default test: pcie_phy_smoke_test)"
	@echo "  make run TESTNAME=<name>  - run any other test from testlists/pcie_phy_regression.list"
	@echo "  make clean                - remove work lib / logs / waveform dumps"
