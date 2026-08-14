`ifndef PCIE_PHY_EP_L0_SEQ_INCLUDED_
`define PCIE_PHY_EP_L0_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_l0_seq
// Mirrors pcie_phy_rc_l0_seq exactly.
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_l0_seq extends uvm_sequence #(pcie_phy_ep_tx);
  `uvm_object_utils(pcie_phy_ep_l0_seq)

  pcie_phy_ep_tx req;
  ltssm_state_e final_state;

  extern function new(string name = "pcie_phy_ep_l0_seq");
  extern task body();

endclass : pcie_phy_ep_l0_seq

function pcie_phy_ep_l0_seq::new(string name = "pcie_phy_ep_l0_seq");
  super.new(name);
endfunction : new

task pcie_phy_ep_l0_seq::body();
  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  req = pcie_phy_ep_tx::type_id::create("req");
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
