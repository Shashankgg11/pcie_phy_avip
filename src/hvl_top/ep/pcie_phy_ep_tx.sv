 
`ifndef PCIE_PHY_EP_TX_INCLUDED_

`define PCIE_PHY_EP_TX_INCLUDED_
//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_tx
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_tx extends uvm_sequence_item;
  `uvm_object_utils(pcie_phy_ep_tx)
  pcie_phy_ep_agent_config pcie_phy_ep_agent_cfg_h;
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
  //Uses link_width_e instead of using a raw lane count.
  rand link_width_e requested_width;
 
  //-------------------------------------------------------
  // Variable: task_id
  //Used to select the driver_bfm task when is_bfm_verify_item is 0.
  //Each value selects one driver_bfm task.
  //-------------------------------------------------------
  pcie_phy_ltssm_task_e task_id;

  //-------------------------------------------------------
  // Response fields - updated by driver_proxy after calling the driver_bfm task.
  //These fields are also present in pcie_phy_rc_tx.
  //-------------------------------------------------------
  ltssm_state_e      rsp_state;
  detect_substate_e  rsp_detect_substate;
  polling_substate_e rsp_polling_substate;
  config_substate_e  rsp_config_substate;

  //Variable: l0p_request
  //Requests the link to enter L0p after reaching L0.
  //This is an EP-side request, so it is kept here instead of the RC side.
  //It is only used when target_state is L0_ST.
  rand bit l0p_request;
 
  // NOTE: An error injection field could be added here later, such as forcing a
  // sub-state timeout or symbol-lock loss. The required enum
  // (pcie_phy_error_inject_e) is not currently defined in pcie_phy_pkg.

  // It is left out for now and can be added when the enum is available.
 
  //-------------------------------------------------------

  // Constraints

  //-------------------------------------------------------

  constraint c_default_gen {

    requested_gen == GEN6;

  }
 
  constraint c_default_width {

    requested_width == X8;

  }
 
  constraint c_l0p_only_at_l0 {

    l0p_request -> target_state == L0_ST;

  }
 
  //-------------------------------------------------------

  // External Tasks and Functions

  //-------------------------------------------------------

  extern function new(string name = "pcie_phy_ep_tx");

  extern virtual function void do_print(uvm_printer printer);
 
endclass : pcie_phy_ep_tx
 
//--------------------------------------------------------------------------------------------

// Construct: new

//--------------------------------------------------------------------------------------------

function pcie_phy_ep_tx::new(string name = "pcie_phy_ep_tx");

  super.new(name);

endfunction : new
 
//--------------------------------------------------------------------------------------------

// Function: do_print
//--------------------------------------------------------------------------------------------

function void pcie_phy_ep_tx::do_print(uvm_printer printer);

  super.do_print(printer);

  printer.print_string("target_state",    target_state.name());

  printer.print_string("requested_gen",   requested_gen.name());

  printer.print_string("requested_width", requested_width.name());
  printer.print_string("task_id", task_id.name());
  printer.print_string("rsp_state", rsp_state.name());

  printer.print_field ("l0p_request",     l0p_request, 1);

endfunction : do_print
 
`endif
