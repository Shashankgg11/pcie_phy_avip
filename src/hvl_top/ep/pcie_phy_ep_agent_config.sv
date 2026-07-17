`ifndef PCIE_PHY_EP_AGENT_CONFIG_INCLUDED_
`define PCIE_PHY_EP_AGENT_CONFIG_INCLUDED_
 
class pcie_phy_ep_agent_config extends uvm_object;
  `uvm_object_utils(pcie_phy_ep_agent_config)
 
  //Used for creating the agent in either passive or active mode
  uvm_active_passive_enum is_active = UVM_ACTIVE;
 
  //Used for enabling the EP agent's functional coverage
  bit has_coverage;
 
  //Identifies this Endpoint instance (systems with multiple Endpoints on a switch
  //fabric would have one of these per device)
  int ep_id;
 
  //-------------------------------------------------------
  // Link capability (advertised)
  //-------------------------------------------------------
 
  //Highest Gen the EP is capable of - caps how far SPEED_UPGRADE_SEQUENCE is allowed
  //to walk
  pcie_gen_e max_link_speed = GEN6;
 
  //Gen this test wants the link trained to for this run (<= max_link_speed)
  rand pcie_gen_e target_link_speed;
 
  //Widest link the EP can support
  link_width_e max_link_width = X16;
 
  //Lanes actually driven/monitored by the EP for the current test profile
  int active_lanes = ACTIVE_LANES;
 
  //N_FTS value the EP advertises in Symbol 3 of its TS1/TS2. Defaults to NTFS_EP -
  //override per test if you need to exercise a different value.
  bit [7:0] ntfs = NTFS_EP;
 
  //Whether the EP is willing to negotiate FLIT_MODE at all. Ignored (forced 1) once
  //target_link_speed reaches FLIT_MODE_MANDATORY_FROM_GEN.
  bit flit_mode_capable = 1;
 
  //What the EP proposes for actual data transfer once L0 is reached, subject to
  //partner negotiation and the GEN6-mandatory override
  data_transfer_mode_e preferred_transfer_mode = FLIT_MODE;
 
  //Test-level override to force Modified TS1/TS2 Ordered-Set usage from the start
  bit use_modified_ts1_ts2_ordered_set;
 
  //-------------------------------------------------------
  // EP-specific role behavior
  //-------------------------------------------------------
 
  //EP is always the Downstream Port on a direct RC<->EP link - it responds to
  //Configuration.Linkwidth.Start rather than initiating it.
  bit is_upstream_port = 0;
 
  //Convenience flag read directly by run_linkwidth_start()/run_linkwidth_accept()
  //instead of every task re-deriving it from is_upstream_port
  bit responds_to_linkwidth_start = 1;
 
  //Whether this EP will accept a later width upconfigure request (a Configuration
  //re-entry that widens the link beyond what was first negotiated)
  bit supports_upconfigure = 1;
 
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
  // at the EP without touching the package-level defaults.
  //-------------------------------------------------------
  bit rx_detect_assumed            = RX_DETECT_ASSUMED;
  bit pll_lock_assumed             = PLL_LOCK_ASSUMED;
  bit electrical_idle_exit_assumed = ELECTRICAL_IDLE_EXIT_ASSUMED;
  bit eq_done_assumed              = EQ_DONE_ASSUMED;
 
    //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_ep_agent_config");
  extern function void do_print(uvm_printer printer);
  //-------------------------------------------------------
  // Constraints
  //-------------------------------------------------------
 
  //Constraint: c_target_speed_within_max
  //Never target a speed the EP doesn't claim to support
  constraint c_target_speed_within_max {
    target_link_speed <= max_link_speed;
  }
 
endclass : pcie_phy_ep_agent_config
 
//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - pcie_phy_ep_agent_config
//--------------------------------------------------------------------------------------------
function pcie_phy_ep_agent_config::new(string name = "pcie_phy_ep_agent_config");
  super.new(name);
endfunction : new
 
 
//--------------------------------------------------------------------------------------------
// Function: do_print method
// Print method can be added to display the data members values
//
// Parameters :
// printer  - uvm_printer
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_agent_config::do_print(uvm_printer printer);
  super.do_print(printer);
 
  printer.print_string ("is_active", is_active.name());
  printer.print_field  ("ep_id", ep_id, $bits(ep_id), UVM_DEC);
  printer.print_field  ("has_coverage", has_coverage, $bits(has_coverage), UVM_DEC);
  printer.print_string ("max_link_speed", max_link_speed.name());
  printer.print_string ("target_link_speed", target_link_speed.name());
  printer.print_string ("max_link_width", max_link_width.name());
  printer.print_field  ("active_lanes", active_lanes, $bits(active_lanes), UVM_DEC);
  printer.print_field  ("ntfs", ntfs, $bits(ntfs), UVM_HEX);
  printer.print_field  ("is_upstream_port", is_upstream_port, $bits(is_upstream_port), UVM_DEC);
  printer.print_field  ("supports_upconfigure", supports_upconfigure,
                         $bits(supports_upconfigure), UVM_DEC);
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
