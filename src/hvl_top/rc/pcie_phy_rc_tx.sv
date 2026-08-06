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

  //Variable: is_bfm_verify_item
  //Test/debug-only. When set, the driver_proxy dispatches strictly off requested_task
  //instead of target_state - used by BFM-exerciser verification sequences to call a
  //specific driver_bfm task directly, regardless of LTSSM protocol ordering.
  bit is_bfm_verify_item;

  //Variable: requested_task
  //Only meaningful when is_bfm_verify_item == 1.
  bfm_verify_task_e requested_task;
 
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

  //-------------------------------------------------------
  // Variable: task_id
  // THE real dispatch selector, used whenever is_bfm_verify_item == 0. Names exactly one
  // driver_bfm task - the driver_proxy calls that task and nothing else; it never infers what
  // to run from target_state (too coarse - POLLING_ST alone can't distinguish
  // Polling.Active/Compliance/Configuration). Each per-state sequence sets this directly.
  //-------------------------------------------------------
  pcie_phy_ltssm_task_e task_id;

  //-------------------------------------------------------
  // Response fields - filled in by driver_proxy AFTER dispatching to the real driver_bfm
  // task, with whatever that task's actual output arguments were. A sequence (or the virtual
  // sequence orchestrating it) reads these back on THIS SAME req object after finish_item()
  // returns, to decide what to do next - retry, advance, or fail - instead of assuming
  // success.
  //-------------------------------------------------------
  ltssm_state_e      rsp_state;
  detect_substate_e  rsp_detect_substate;
  polling_substate_e rsp_polling_substate;
  config_substate_e  rsp_config_substate;
 
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
  printer.print_string("task_id", task_id.name());
  printer.print_string("rsp_state", rsp_state.name());
endfunction : do_print
`endif
