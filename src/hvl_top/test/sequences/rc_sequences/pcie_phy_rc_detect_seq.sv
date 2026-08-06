`ifndef PCIE_PHY_RC_DETECT_SEQ_INCLUDED_
`define PCIE_PHY_RC_DETECT_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_detect_seq
// Detect Seq for the Downstream Port (Root Complex). Runs Detect.Quiet, then Detect.Active,
// reading the REAL response after each - if run_detect_active() genuinely reports DETECT_ST
// (no receiver found), this sequence loops back to Detect.Quiet again rather than assuming
// success, exactly like the real link would retry.
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_detect_seq extends uvm_sequence #(pcie_phy_rc_tx);
  `uvm_object_utils(pcie_phy_rc_detect_seq)

  pcie_phy_rc_tx req;

  //Variable: final_state
  //Read by the caller (a virtual sequence) after body() returns to know whether Detect
  //actually succeeded (POLLING_ST) - this sequence itself does not retry forever.
  ltssm_state_e final_state;

  //Variable: max_attempts
  int unsigned max_attempts = 10;

  extern function new(string name = "pcie_phy_rc_detect_seq");
  extern task body();

endclass : pcie_phy_rc_detect_seq

function pcie_phy_rc_detect_seq::new(string name = "pcie_phy_rc_detect_seq");
  super.new(name);
endfunction : new

task pcie_phy_rc_detect_seq::body();
  detect_substate_e cur_substate = DETECT_QUIET;

  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  for (int unsigned attempt = 0; attempt < max_attempts; attempt++) begin

    req = pcie_phy_rc_tx::type_id::create($sformatf("req_%0d", attempt));
    start_item(req);
    if (!req.randomize()) `uvm_error(get_type_name(), "Randomization failed")
    req.is_bfm_verify_item = 1'b0;
    req.task_id = (cur_substate == DETECT_QUIET) ? LTSSM_TASK_DETECT_QUIET : LTSSM_TASK_DETECT_ACTIVE;
    finish_item(req);

    if (cur_substate == DETECT_QUIET) begin
      cur_substate = req.rsp_detect_substate; //Detect.Quiet always advances to Detect.Active
    end
    else begin
      final_state = req.rsp_state;
      if (final_state == POLLING_ST) return;   //success
      cur_substate = DETECT_QUIET;             //retry
    end
  end

  `uvm_error(get_type_name(), $sformatf("Detect did not reach POLLING_ST within %0d attempts", max_attempts))
endtask : body

`endif
