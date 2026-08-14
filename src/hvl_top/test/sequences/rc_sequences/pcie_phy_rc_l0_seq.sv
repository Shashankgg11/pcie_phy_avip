`ifndef PCIE_PHY_RC_L0_SEQ_INCLUDED_
`define PCIE_PHY_RC_L0_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_l0_seq
// L0 Seq for the Downstream Port (Root Complex). Unlike every other sequence in this chain,
// run_l0() runs indefinitely during healthy operation - it only returns on a Recovery-
// triggering condition (speed mismatch, receive errors, directed request, idle timeout).
// The driver_proxy dispatches it fire-and-forget and reports rsp_state=L0_ST immediately -
// reaching L0 IS the success signal here, this sequence does not wait for something to
// eventually go wrong.
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_l0_seq extends uvm_sequence #(pcie_phy_rc_tx);
  `uvm_object_utils(pcie_phy_rc_l0_seq)

  pcie_phy_rc_tx req;
  ltssm_state_e final_state;

  extern function new(string name = "pcie_phy_rc_l0_seq");
  extern task body();

endclass : pcie_phy_rc_l0_seq

function pcie_phy_rc_l0_seq::new(string name = "pcie_phy_rc_l0_seq");
  super.new(name);
endfunction : new

task pcie_phy_rc_l0_seq::body();
  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  req = pcie_phy_rc_tx::type_id::create("req");
  start_item(req);
  if (!req.randomize()) `uvm_error(get_type_name(), "Randomization failed")
  req.is_bfm_verify_item = 1'b0;
  req.task_id = LTSSM_TASK_L0;
  finish_item(req);

  final_state = req.rsp_state;

  if (final_state == L0_ST) begin
    `uvm_info(get_type_name(), "Reached L0 - link trained", UVM_LOW)
  end
  else begin
    `uvm_error(get_type_name(), $sformatf("Unexpected rsp_state entering L0: %s", final_state.name()))
  end
endtask : body

`endif
