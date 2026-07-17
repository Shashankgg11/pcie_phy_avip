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
 
  //Variable: requested_gen
  // Uses pcie_gen_e directly since the package already models speed as
  // a proper enum (GEN1..GEN6) rather than a raw Sym4 hex value.
  rand pcie_gen_e requested_gen;
 
  //Variable: requested_width
  // Drives a width-change directive during Configuration.Linkwidth.Start —
  // RC is the side that PROPOSES lane numbers, so this field is where a
  // test forces a reduced-width negotiation attempt. Uses link_width_e.
  rand link_width_e requested_width;
 
  //Variable: force_lane_reversal
  // RC-specific directive: forces the RC BFM to assign lane numbers in
  // reverse order instead of the normal sequential assignment, to
  // exercise the EP's lane-reversal detection logic. Not applicable on
  // the EP side, which only ever detects/echoes.
  rand bit force_lane_reversal;
 
  // NOTE: an error-injection directive field would normally live here
  // too, but the enum type it needs (pcie_phy_error_inject_e) isn't
  // defined in pcie_phy_pkg yet. Left out rather than referencing an
  // undefined type — add once that enum exists in the package.
 
  //-------------------------------------------------------
  // Constraints
  //-------------------------------------------------------
  constraint c_default_gen {
    requested_gen == GEN6;
  }
 
  constraint c_default_width {
    requested_width == X4;
  }
 
  constraint c_reversal_only_full_width {
    force_lane_reversal -> requested_width == X4;
  }
 
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
// Prints every directive field so waveform-less log debug is possible.
//
// Parameters:
//  printer - uvm_printer
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_tx::do_print(uvm_printer printer);
  super.do_print(printer);
  printer.print_string("target_state",        target_state.name());
  printer.print_string("requested_gen",       requested_gen.name());
  printer.print_string("requested_width",     requested_width.name());
  printer.print_field ("force_lane_reversal", force_lane_reversal, 1);
endfunction : do_print
`endif
