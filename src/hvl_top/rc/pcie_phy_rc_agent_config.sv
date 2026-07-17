`ifndef PCIE_PHY_RC_AGENT_CONFIG_INCLUDED_
`define PCIE_PHY_RC_AGENT_CONFIG_INCLUDED_
 
class pcie_phy_rc_agent_config extends uvm_object;
  `uvm_object_utils(pcie_phy_rc_agent_config)
 
  //Used for creating the agent in either passive or active mode
  uvm_active_passive_enum is_active = UVM_ACTIVE;
 
  //Used for enabling the RC agent's functional coverage
  bit has_coverage;
 
  //Identifies this Root Complex / Root Port instance (systems with multiple Root Ports
  //would have one of these per port)
  int rc_id;
 
  //-------------------------------------------------------
  // Link capability (advertised)
  //-------------------------------------------------------
 
  //Highest Gen the RC is capable of - caps how far SPEED_UPGRADE_SEQUENCE is allowed
  //to walk
  pcie_gen_e max_link_speed = GEN6;
 
  //Gen this test wants the link trained to for this run (<= max_link_speed)
  rand pcie_gen_e target_link_speed;
 
  //Widest link the RC can support
  link_width_e max_link_width = X16;
 
  //Lanes actually driven/monitored by the RC for the current test profile
  int active_lanes = ACTIVE_LANES;
 
  //N_FTS value the RC advertises in Symbol 3 of its TS1/TS2. Defaults to NTFS_RC -
  //override per test if you need to exercise a different value.
  bit [7:0] ntfs = NTFS_RC;
 
  //Whether the RC is willing to negotiate FLIT_MODE at all. Ignored (forced 1) once
  //target_link_speed reaches FLIT_MODE_MANDATORY_FROM_GEN.
  bit flit_mode_capable = 1;
 
  //What the RC proposes for actual data transfer once L0 is reached, subject to
  //partner negotiation and the GEN6-mandatory override
  data_transfer_mode_e preferred_transfer_mode = FLIT_MODE;
 
  //Test-level override to force Modified TS1/TS2 Ordered-Set usage from the start
  bit use_modified_ts1_ts2_ordered_set;
 
  //-------------------------------------------------------
  // RC-specific role behavior
  //-------------------------------------------------------
 
  //RC is always the Upstream Port on a direct RC<->EP link - it drives
  //Configuration.Linkwidth.Start first (the EP, as Downstream Port, responds).
  //Kept as a field (rather than hardcoded in the BFM) so a loopback/compliance test
  //can flip it if needed.
  bit is_upstream_port = 1;
 
  //Variable: initiates_linkwidth_start
  //Convenience flag mirroring is_upstream_port, read directly by run_linkwidth_start()
  //instead of every task re-deriving it
  bit initiates_linkwidth_start = 1;
 
  //-------------------------------------------------------
  // Timing knobs (override the package defaults per instance/test)
  //-------------------------------------------------------
  int detect_timeout_ms   = DETECT_TIMEOUT_MS;
  int polling_timeout_ms  = POLLING_TIMEOUT_MS;
  int config_timeout_ms   = CONFIG_TIMEOUT_MS;
  int recovery_timeout_ms = RECOVERY_TIMEOUT_MS;
 
  //-------------------------------------------------------
  // Electrical Sub-block assumption overrides
  // Flip any of these to 0 in a negative test to model an electrical-layer failure
  // at the RC without touching the package-level defaults.
  //-------------------------------------------------------
  bit rx_detect_assumed            = RX_DETECT_ASSUMED;
  bit pll_lock_assumed             = PLL_LOCK_ASSUMED;
  bit electrical_idle_exit_assumed = ELECTRICAL_IDLE_EXIT_ASSUMED;
  bit eq_done_assumed              = EQ_DONE_ASSUMED;
 
 
  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_agent_config");
  extern function void do_print(uvm_printer printer);
  //-------------------------------------------------------
  // Constraints
  //-------------------------------------------------------
 
  //Constraint: c_target_speed_within_max
  //Never target a speed the RC doesn't claim to support
  constraint c_target_speed_within_max {
    target_link_speed <= max_link_speed;
  }
 
endclass : pcie_phy_rc_agent_config
 
//--------------------------------------------------------------------------------------------
// Construct: new
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_agent_config::new(string name = "pcie_phy_rc_agent_config");
  super.new(name);
endfunction : new
 
 
//--------------------------------------------------------------------------------------------
// Function: do_print method
// Print method can be added to display the data members values
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_agent_config::do_print(uvm_printer printer);
  super.do_print(printer);
  printer.print_string ("is_active", is_active.name());
  printer.print_field  ("rc_id", rc_id, $bits(rc_id), UVM_DEC);
  printer.print_field  ("has_coverage", has_coverage, $bits(has_coverage), UVM_DEC);
  printer.print_string ("max_link_speed", max_link_speed.name());
  printer.print_string ("target_link_speed", target_link_speed.name());
  printer.print_string ("max_link_width", max_link_width.name());
  printer.print_field  ("active_lanes", active_lanes, $bits(active_lanes), UVM_DEC);
  printer.print_field  ("ntfs", ntfs, $bits(ntfs), UVM_HEX);
  printer.print_field  ("is_upstream_port", is_upstream_port, $bits(is_upstream_port), UVM_DEC);
  printer.print_field  ("flit_mode_capable", flit_mode_capable, $bits(flit_mode_capable), UVM_DEC);
  printer.print_string ("preferred_transfer_mode", preferred_transfer_mode.name());
  printer.print_field  ("use_modified_ts1_ts2_ordered_set", use_modified_ts1_ts2_ordered_set,
                         $bits(use_modified_ts1_ts2_ordered_set), UVM_DEC);
  printer.print_field  ("detect_timeout_ms", detect_timeout_ms, $bits(detect_timeout_ms), UVM_DEC);
  printer.print_field  ("polling_timeout_ms", polling_timeout_ms, $bits(polling_timeout_ms), UVM_DEC);
  printer.print_field  ("config_timeout_ms", config_timeout_ms, $bits(config_timeout_ms), UVM_DEC);
  printer.print_field  ("recovery_timeout_ms", recovery_timeout_ms, $bits(recovery_timeout_ms), UVM_DEC);
  printer.print_field  ("rx_detect_assumed", rx_detect_assumed, $bits(rx_detect_assumed), UVM_DEC);
  printer.print_field  ("pll_lock_assumed", pll_lock_assumed, $bits(pll_lock_assumed), UVM_DEC);
 
endfunction : do_print
 
`endif
