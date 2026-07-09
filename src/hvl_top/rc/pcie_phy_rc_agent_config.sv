`ifndef PCIE_PHY_RC_AGENT_CONFIG_INCLUDED_
`define PCIE_PHY_RC_AGENT_CONFIG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_agent_config
// Used as the configuration class for pcie_phy rc agent (Downstream Port (Root Complex)), configures rate/width capability and coverage enable
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_agent_config extends uvm_object;
  `uvm_object_utils(pcie_phy_rc_agent_config)

  //Variable: is_active
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  //Variable: has_coverage
  bit has_coverage;

  //Variable: supported_rates
  rand bit [6:0] supported_rates;

  //Variable: flit_mode_supported
  rand bit flit_mode_supported;

  //Variable: sris_capable
  rand bit sris_capable;

  //Variable: max_lanes
  rand int max_lanes;

  //Variable: upconfigure_capable
  rand bit upconfigure_capable;

  // TODO: remaining cfg fields (Tx presets per lane, compliance settings, retimer flags, ...)

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_agent_config");
  extern virtual function void do_print(uvm_printer printer);

endclass : pcie_phy_rc_agent_config

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_rc_agent_config
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_agent_config::new(string name = "pcie_phy_rc_agent_config");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: do_print
// <Description_here>
//
// Parameters:
//  printer - uvm_printer
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_agent_config::do_print(uvm_printer printer);
  // TODO: print fields via printer.print_field/print_string
endfunction : do_print


`endif
