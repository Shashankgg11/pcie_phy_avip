`ifndef PCIE_PHY_EP_DETECT_SEQ_INCLUDED_
`define PCIE_PHY_EP_DETECT_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_detect_seq
// Mirrors pcie_phy_rc_detect_seq exactly - see that file for the reasoning.
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_detect_seq extends uvm_sequence #(pcie_phy_ep_tx);
  `uvm_object_utils(pcie_phy_ep_detect_seq)

  pcie_phy_ep_tx req;
  ltssm_state_e final_state;
  int unsigned max_attempts = 10;

  extern function new(string name = "pcie_phy_ep_detect_seq");
  extern task body();

endclass : pcie_phy_ep_detect_seq

function pcie_phy_ep_detect_seq::new(string name = "pcie_phy_ep_detect_seq");
  super.new(name);
endfunction : new

task pcie_phy_ep_detect_seq::body();
  detect_substate_e cur_substate = DETECT_QUIET;

  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  for (int unsigned attempt = 0; attempt < max_attempts; attempt++) begin

    req = pcie_phy_ep_tx::type_id::create($sformatf("req_%0d", attempt));
    start_item(req);
    if (!req.randomize()) `uvm_error(get_type_name(), "Randomization failed")
    req.is_bfm_verify_item = 1'b0;
    req.task_id = (cur_substate == DETECT_QUIET) ? LTSSM_TASK_DETECT_QUIET : LTSSM_TASK_DETECT_ACTIVE;
    finish_item(req);

    if (cur_substate == DETECT_QUIET) begin
      cur_substate = req.rsp_detect_substate;
    end
    else begin
      final_state = req.rsp_state;
      if (final_state == POLLING_ST) return;
      cur_substate = DETECT_QUIET;
    end
  end

  `uvm_error(get_type_name(), $sformatf("Detect did not reach POLLING_ST within %0d attempts", max_attempts))
endtask : body

`endif
