`ifndef PCIE_PHY_RC_AGENT_CONFIG_INCLUDED_
`define PCIE_PHY_RC_AGENT_CONFIG_INCLUDED_
 
class pcie_phy_rc_agent_config extends uvm_object;
  `uvm_object_utils(pcie_phy_rc_agent_config)
 
  //Used to create the agent in active or passive mode
  uvm_active_passive_enum is_active = UVM_ACTIVE;
 
  //Used to enable functional coverage for the RC agent
  bit has_coverage;
 
  //Identifies this Root Complex / Root Port instance
  int rc_id;
 
  //-------------------------------------------------------
  // Link capability
  //-------------------------------------------------------
 
  //Highest Gen supported by the RC. This limits the SPEED_UPGRADE_SEQUENCE
  //to the supported speed
  pcie_gen_e max_link_speed = GEN6;
 
  //Target Gen for this test. It should be less than or equal to max_link_speed
  rand pcie_gen_e target_link_speed;
 
  //Maximum link width supported by the RC
  link_width_e max_link_width = X16;
  
  int detect_timeout_cycles = 24; 
  int config_timeout_ts_count = 50; //Changed from 2. Linkwidth.Start needs multiple round trips
                                     //even when reception is good. 50 gives enough time for
                                     //retries and is also used by the other Configuration
                                     //substates.
  //Number of lanes used by the RC in the current test
  int active_lanes = ACTIVE_LANES;
 
  //N_FTS value sent by the RC in Symbol 3 of TS1/TS2. Uses NTFS_RC by default
  //and can be changed in the test if needed
  bit [7:0] ntfs = NTFS_RC;
 
  //Variable: initial_disparity
  running_disparity_e initial_disparity = RD_MINUS;

  //Variable: link_number
  //RC selects this value and sends it during Configuration.Linkwidth.Start.
  //The EP gets its Link Number from the RC.
  bit [7:0] link_number = 8'h00;

  //-------------------------------------------------------
  // Default Symbol 4/5 control values used by the RC in TS
  //These values can be changed by a task or test when needed
  //-------------------------------------------------------
  bit       default_autonomous_change = 1'b0;
  bit [1:0] default_elbc              = 2'b11; //Modified TS1/TS2 supported
  bit       default_no_scrambling     = 1'b0;
  bit       default_loopback          = 1'b0;
  bit       default_disable_link      = 1'b0;
  bit       default_hot_reset         = 1'b0;
 
  //Shows whether the RC supports FLIT_MODE. It is forced to 1 when
  //target_link_speed reaches FLIT_MODE_MANDATORY_FROM_GEN.
  bit flit_mode_capable = 1;
 
  //Transfer mode preferred by the RC when the link reaches L0
  //This depends on partner negotiation and the GEN6 requirement
  data_transfer_mode_e preferred_transfer_mode = FLIT_MODE;

  //Variable: use_modified_ts1_ts2_ordered_set
  //Test option to use Modified TS1/TS2 Ordered Sets from the beginning
  bit use_modified_ts1_ts2_ordered_set;

  //-------------------------------------------------------
  // RC-specific role behavior
  //-------------------------------------------------------
 
  //RC is the Upstream Port on a direct RC to EP link. It sends
  //Configuration.Linkwidth.Start first and the EP responds.
  bit is_upstream_port = 1;
 
  //Used by run_linkwidth_start() to show that the RC starts the link width process
  //instead of checking it again in every task
  bit initiates_linkwidth_start = 1;
 
  //-------------------------------------------------------
  // Timing settings
  //These values can be changed for a specific instance or test
  //-------------------------------------------------------
  int detect_timeout_ms   = DETECT_TIMEOUT_MS;
  int polling_timeout_ms  = POLLING_TIMEOUT_MS;
  int config_timeout_ms   = CONFIG_TIMEOUT_MS;
  int recovery_timeout_ms = RECOVERY_TIMEOUT_MS;
 
  //-------------------------------------------------------
  // Electrical Sub-block assumptions
  //These values can be overridden when needed
  //-------------------------------------------------------
  bit rx_detect_assumed            = RX_DETECT_ASSUMED;
  bit pll_lock_assumed             = PLL_LOCK_ASSUMED;
  bit electrical_idle_exit_assumed = ELECTRICAL_IDLE_EXIT_ASSUMED;
  bit eq_done_assumed              = EQ_DONE_ASSUMED;
 
  //-------------------------------------------------------
  // Test-injection settings
  //-------------------------------------------------------
 
  // External Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_agent_config");
  extern function void do_print(uvm_printer printer);
 
  //-------------------------------------------------------
  // Constraints
  //-------------------------------------------------------
 
  //Constraint: c_target_speed_within_max
  //Makes sure the target speed is supported by the RC
  constraint c_target_speed_within_max {
    target_link_speed <= max_link_speed;
  }
 
endclass : pcie_phy_rc_agent_config
 
//Construct: new
function pcie_phy_rc_agent_config::new(string name = "pcie_phy_rc_agent_config");
  super.new(name);
endfunction : new
 
 
//Function: do_print method
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
  printer.print_string ("initial_disparity", initial_disparity.name());
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
