`ifndef PCIE_PHY_RC_TX_INCLUDED_
`define PCIE_PHY_RC_TX_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_tx
// This class holds the data items required to drive PHY directives
// to the Downstream Port (Root Complex) LTSSM and also holds methods that manipulate those items.
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_tx extends uvm_sequence_item;
  `uvm_object_utils(pcie_phy_rc_tx)

  pcie_phy_rc_agent_config pcie_phy_rc_agent_cfg_h;

  //Variable: target_state
  rand ltssm_state_e target_state;

  // TODO: directive fields — speed change, width change, error-injection type, L0p request, ...

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_tx");
  extern virtual function void do_print(uvm_printer printer);

endclass : pcie_phy_rc_tx

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_rc_tx
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_tx::new(string name = "pcie_phy_rc_tx");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: do_print
// <Description_here>
//
// Parameters:
//  printer - uvm_printer
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_tx::do_print(uvm_printer printer);
  // TODO: printer.print_string/print_field per directive field
endfunction : do_print


`endif
