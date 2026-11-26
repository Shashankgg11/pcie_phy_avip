# ================================================================
# PCIe PHY Verification Makefile
# ================================================================

# ------------------------------------------------
# Default target
# ------------------------------------------------
.DEFAULT_GOAL := usage

# ------------------------------------------------
# VCS Compilation Command
# ------------------------------------------------
VCS_CMD_RAND = vcs -full64 -sverilog +v2k \
               -debug_access+all \
               -debug_acc+pp+dmptf \
               -ntb_opts uvm-1.1 \
               +ntb_random_seed_automatic \
               +memcbk \
               +vcs+fsdbon+all \
               -override_timescale=1ns/1ps

# ------------------------------------------------
# Default Simulation Variables
# ------------------------------------------------
ifndef test
override test = DllSimpleTest
endif

ifndef uvm_verbosity
override uvm_verbosity = UVM_LOW
endif

ifndef test_folder
override test_folder = $(test)
endif

# ================================================================
# ALL
# ================================================================
all:
	@$(MAKE) clean
	@$(MAKE) compile
	@$(MAKE) simulate test=$(test) uvm_verbosity=$(uvm_verbosity)

# ================================================================
# COMPILE
# ================================================================
compile:
	@echo ""
	@echo "================================================================"
	@echo "                    COMPILATION"
	@echo "================================================================"
	@echo ""
	$(VCS_CMD_RAND) \
	-l PciePhyCompile.log \
	+plusarg_ignore \
	-f ../pcie_phy_compile.f
	@echo ""
	@echo "Compilation completed."
	@echo ""
	@$(MAKE) compile_war_err

# ================================================================
# SIMULATE
# ================================================================
simulate:
	@echo ""
	@echo "================================================================"
	@echo "                    SIMULATION"
	@echo "================================================================"
	@echo ""
	@echo "Test Name   : $(test)"
	@echo "Test Folder : $(test_folder)"
	@echo "Verbosity   : $(uvm_verbosity)"
	@echo ""
	@mkdir -p $(test_folder)
	cd $(test_folder) && ../simv \
	+UVM_TESTNAME=$(test) \
	+UVM_VERBOSITY=$(uvm_verbosity) \
	-l $(test).log
	@echo ""
	@echo "Generating coverage report..."
	@echo ""
	@mkdir -p $(test_folder)/urgReport
	urg -report $(test_folder)/urgReport -dir ../simv.vdb
	@echo ""
	@echo "Coverage report generated:"
	@echo "$(test_folder)/urgReport/dashboard.html"
	@echo ""
	@$(MAKE) simulate_war_err

# ================================================================
# COMPILATION REPORT
# ================================================================
compile_war_err:
	@echo ""
	@echo "----------------------------------------------------------------"
	@echo "                 Compilation Report"
	@echo "----------------------------------------------------------------"
	@echo ""
	@echo "Warnings:"
	@grep "^Warning" PciePhyCompile.log || true
	@echo ""
	@echo "Errors:"
	@grep "^Error" PciePhyCompile.log || true
	@echo ""
	@echo "Log file path:"
	@echo "PciePhyCompile.log"
	@echo ""
	@echo "----------------------------------------------------------------"
	@echo "----------------------------------------------------------------"
	@echo ""

# ================================================================
# SIMULATION REPORT
# ================================================================
simulate_war_err:
	@echo ""
	@echo "----------------------------------------------------------------"
	@echo "                  Simulation Report"
	@echo "----------------------------------------------------------------"
	@echo ""
	@echo "Test Name       : $(test)"
	@echo "UVM Verbosity   : $(uvm_verbosity)"
	@echo ""
	@echo "UVM_Fatal:"
	@grep "FATAL" $(test_folder)/$(test).log || true
	@echo ""
	@echo "UVM_Error:"
	@grep "ERROR" $(test_folder)/$(test).log || true
	@echo ""
	@echo "UVM_Warning:"
	@grep "WARN" $(test_folder)/$(test).log || true
	@echo ""
	@echo "Test Name:"
	@echo "$(test)"
	@echo ""
	@echo "Log file path:"
	@echo "less -R $(test_folder)/$(test).log"
	@echo ""
	@echo "Waveform:"
	@echo "verdi -ssf $(test_folder)/novas.fsdb &"
	@echo ""
	@echo "Coverage:"
	@echo "firefox $(test_folder)/urgReport/dashboard.html &"
	@echo ""
	@echo "----------------------------------------------------------------"
	@echo "----------------------------------------------------------------"
	@echo ""

# ================================================================
# WAVEFORM
# ================================================================
wave:
	@echo ""
	@echo "================================================================"
	@echo "                    WAVEFORM"
	@echo "================================================================"
	@echo ""
	@if [ -f $(test_folder)/novas.fsdb ]; then \
		echo "Opening waveform: $(test_folder)/novas.fsdb"; \
		verdi -ssf $(test_folder)/novas.fsdb & \
	else \
		echo "ERROR: FSDB file not found:"; \
		echo "$(test_folder)/novas.fsdb"; \
	fi
	@echo ""

# ================================================================
# COVERAGE
# ================================================================
cov:
	@echo ""
	@echo "================================================================"
	@echo "                    COVERAGE"
	@echo "================================================================"
	@echo ""
	@if [ -d simv.vdb ]; then \
		mkdir -p $(test_folder)/urgReport; \
		urg -report $(test_folder)/urgReport -dir simv.vdb; \
		echo ""; \
		echo "Coverage report generated:"; \
		echo "$(test_folder)/urgReport/dashboard.html"; \
	else \
		echo "ERROR: simv.vdb not found."; \
		echo "Run 'make simulate test=$(test)' first."; \
	fi
	@echo ""

# ================================================================
# CLEAN
# ================================================================
clean:
	@echo ""
	@echo "Cleaning simulation files..."
	@echo ""
	rm -rf csrc \
	       simv \
	       verdiLog \
	       simv.daidir \
	       simv.vdb \
	       work \
	       *.bak \
	       *.vpd \
	       transcript \
	       waves.shm \
	       *.wlf \
	       mylib \
	       lib \
	       *.vstf \
	       .restart* \
	       urgReport \
	       *.so \
	       vc_hdrs.h \
	       *.log \
	       *.fsdb \
	       *.key \
	       nWaveLog \
	       vfastLog \
	       *.conf \
	       *.vcd \
	       PciePhy* \
	       via.rc \
	       novas.fsdb \
	       novas.rc
	@echo ""
	@echo "Clean completed."
	@echo ""

# ================================================================
# USAGE
# ================================================================
usage:
	@echo ""
	@echo "================================================================"
	@echo "                    PCIe PHY Verification"
	@echo "================================================================"
	@echo ""
	@echo "Usage:"
	@echo ""
	@echo "  make compile"
	@echo "      Compile the complete testbench"
	@echo ""
	@echo "  make simulate"
	@echo "      Run default test: $(test)"
	@echo ""
	@echo "  make simulate test=DllSimpleTest"
	@echo "      Run a specific test"
	@echo ""
	@echo "  make simulate test=DllSimpleTest uvm_verbosity=UVM_HIGH"
	@echo "      Run test with selected UVM verbosity"
	@echo ""
	@echo "  make all test=DllSimpleTest"
	@echo "      Clean + compile + simulate"
	@echo ""
	@echo "  make wave test=DllSimpleTest"
	@echo "      Open FSDB waveform"
	@echo ""
	@echo "  make cov test=DllSimpleTest"
	@echo "      Generate coverage report"
	@echo ""
	@echo "  make clean"
	@echo "      Remove simulation files"
	@echo ""
	@echo "================================================================"
	@echo ""

# ================================================================
# Silent Targets
# ================================================================
.SILENT:
