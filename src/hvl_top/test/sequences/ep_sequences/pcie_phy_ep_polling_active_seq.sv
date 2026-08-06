`ifndef PCIE_PHY_EP_POLLING_ACTIVE_SEQ_INCLUDED_
`define PCIE_PHY_EP_POLLING_ACTIVE_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_polling_active_seq
// Mirrors pcie_phy_rc_polling_active_seq exactly.
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_polling_active_seq extends uvm_sequence #(pcie_phy_ep_tx);
  `uvm_object_utils(pcie_phy_ep_polling_active_seq)

  pcie_phy_ep_tx req;
  ltssm_state_e      final_state;
  polling_substate_e final_polling_substate;

  extern function new(string name = "pcie_phy_ep_polling_active_seq");
  extern task body();

endclass : pcie_phy_ep_polling_active_seq

function pcie_phy_ep_polling_active_seq::new(string name = "pcie_phy_ep_polling_active_seq");
  super.new(name);
endfunction : new

task pcie_phy_ep_polling_active_seq::body();
  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  req = pcie_phy_ep_tx::type_id::create("req");
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
