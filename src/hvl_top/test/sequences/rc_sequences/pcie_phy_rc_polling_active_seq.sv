`ifndef PCIE_PHY_RC_POLLING_ACTIVE_SEQ_INCLUDED_
`define PCIE_PHY_RC_POLLING_ACTIVE_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_polling_active_seq
// Polling.Active Seq for the Downstream Port (Root Complex). One item, one call to
// run_polling_active() - that task itself contains the full drive/receive/count loop, so this
// sequence just needs to send the single item and read back the real result.
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_polling_active_seq extends uvm_sequence #(pcie_phy_rc_tx);
  `uvm_object_utils(pcie_phy_rc_polling_active_seq)

  pcie_phy_rc_tx req;

  //Variable: final_state / final_polling_substate
  //Read by the caller after body() returns.
  ltssm_state_e      final_state;
  polling_substate_e final_polling_substate;

  extern function new(string name = "pcie_phy_rc_polling_active_seq");
  extern task body();

endclass : pcie_phy_rc_polling_active_seq

function pcie_phy_rc_polling_active_seq::new(string name = "pcie_phy_rc_polling_active_seq");
  super.new(name);
endfunction : new

task pcie_phy_rc_polling_active_seq::body();
  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  req = pcie_phy_rc_tx::type_id::create("req");
  start_item(req);
  if (!req.randomize()) `uvm_error(get_type_name(), "Randomization failed")
  req.is_bfm_verify_item = 1'b0;
  req.task_id = LTSSM_TASK_POLLING_ACTIVE;
  finish_item(req);

  final_state             = req.rsp_state;
  final_polling_substate  = req.rsp_polling_substate;

  if (final_state == DETECT_ST) begin
    `uvm_info(get_type_name(), "Polling.Active timed out - back to Detect", UVM_LOW)
  end
  else begin
    `uvm_info(get_type_name(), $sformatf("Polling.Active -> %s", final_polling_substate.name()), UVM_LOW)
  end
endtask : body

`endif
