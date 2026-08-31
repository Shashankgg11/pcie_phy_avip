`ifndef PCIE_PHY_RC_TX_INCLUDED_
`define PCIE_PHY_RC_TX_INCLUDED_
//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_tx
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_tx extends uvm_sequence_item;
  `uvm_object_utils(pcie_phy_rc_tx)
  pcie_phy_rc_agent_config pcie_phy_rc_agent_cfg_h;
 
  //Variable: target_state
  rand ltssm_state_e target_state;

  //Variable: is_bfm_verify_item
  //Used for test and debug. When set, the driver_proxy uses requested_task
  //instead of target_state to call a specific driver_bfm task.
  bit is_bfm_verify_item;

  //Variable: requested_task
  //Used when is_bfm_verify_item is set to 1.
  bfm_verify_task_e requested_task;
 
  //Variable: requested_gen
  //Uses pcie_gen_e since the package already defines GEN1 to GEN6 as an enum.
  rand pcie_gen_e requested_gen;
 
  //Variable: requested_width
  //Used to request a different link width during Configuration.Linkwidth.Start.
  //The RC selects the lane numbers, so the test can use this field to request
  //a smaller link width. Uses link_width_e.
  rand link_width_e requested_width;
 
  //Variable: force_lane_reversal
  //RC-specific option to assign lane numbers in reverse order instead of the
  //normal order. This is used to test the EP lane-reversal detection.
  //This is not used on the EP side.
  rand bit force_lane_reversal;

  //-------------------------------------------------------
  // Variable: task_id
  //Used to select the driver_bfm task when is_bfm_verify_item is 0.
  //Each value selects one driver_bfm task. The sequence sets this value
  //directly instead of using target_state.
  //-------------------------------------------------------
  pcie_phy_ltssm_task_e task_id;

  //-------------------------------------------------------
  // Response fields - updated by the driver_proxy after calling the driver_bfm
  // task. The sequence reads these fields to decide whether to retry, continue,
  // or fail.
  //-------------------------------------------------------
  ltssm_state_e      rsp_state;
  detect_substate_e  rsp_detect_substate;
  polling_substate_e rsp_polling_substate;
  config_substate_e  rsp_config_substate;
 
  // NOTE: An error injection field could be added here later.
  // The required enum (pcie_phy_error_inject_e) is not defined
  // in pcie_phy_pkg yet, so it is left out for now.
 
  //-------------------------------------------------------
  // Constraints
  //-------------------------------------------------------
  constraint c_default_gen {
    requested_gen == GEN6;
  }
 
  constraint c_default_width {
    requested_width == X8;
  }
 
  constraint c_reversal_only_full_width {
    force_lane_reversal -> requested_width == X4;
  }
 
  //-------------------------------------------------------
  // External Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_tx");
  extern virtual function void do_print(uvm_printer printer);
endclass : pcie_phy_rc_tx
//--------------------------------------------------------------------------------------------
// Construct: new
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_tx::new(string name = "pcie_phy_rc_tx");
  super.new(name);
endfunction : new
//--------------------------------------------------------------------------------------------
// Function: do_print
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
