`ifndef PCIE_PHY_RC_CONFIG_LANENUM_SEQ_INCLUDED_
`define PCIE_PHY_RC_CONFIG_LANENUM_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_config_lanenum_seq
// Config Lanenum Seq for the Downstream Port (Root Complex). Steps CFG_LANENUM_WAIT ->
// CFG_LANENUM_ACCEPT. run_configuration_lanenum_accept() can route back to CFG_LANENUM_WAIT
// itself (smaller-link renegotiation) - this sequence follows that real response rather than
// assuming a fixed two-step path.
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_config_lanenum_seq extends uvm_sequence #(pcie_phy_rc_tx);
  `uvm_object_utils(pcie_phy_rc_config_lanenum_seq)

  pcie_phy_rc_tx req;
  ltssm_state_e     final_state;
  config_substate_e final_config_substate;
  int unsigned max_attempts = 10;

  extern function new(string name = "pcie_phy_rc_config_lanenum_seq");
  extern task body();

endclass : pcie_phy_rc_config_lanenum_seq

function pcie_phy_rc_config_lanenum_seq::new(string name = "pcie_phy_rc_config_lanenum_seq");
  super.new(name);
endfunction : new

task pcie_phy_rc_config_lanenum_seq::body();
  config_substate_e cur_substate = CFG_LANENUM_WAIT;

  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  for (int unsigned attempt = 0; attempt < max_attempts; attempt++) begin
    req = pcie_phy_rc_tx::type_id::create($sformatf("req_%0d", attempt));
    start_item(req);
    if (!req.randomize()) `uvm_error(get_type_name(), "Randomization failed")
    req.is_bfm_verify_item = 1'b0;
    req.task_id = (cur_substate == CFG_LANENUM_WAIT) ? LTSSM_TASK_CFG_LANENUM_WAIT
                                                       : LTSSM_TASK_CFG_LANENUM_ACCEPT;
    finish_item(req);

    final_state           = req.rsp_state;
    final_config_substate = req.rsp_config_substate;

    if (final_state == DETECT_ST) begin
      `uvm_error(get_type_name(), "Configuration.Lanenum failed - returned to Detect")
      return;
    end

    if (final_config_substate == CFG_COMPLETE) begin
      `uvm_info(get_type_name(), "Configuration.Lanenum complete - advancing to Complete", UVM_LOW)
      return;
    end

    //Real response drives the next step - CFG_LANENUM_WAIT after an Accept means a genuine
    //smaller-link renegotiation happened, not an assumed fixed path.
    cur_substate = final_config_substate;
  end

  `uvm_error(get_type_name(), $sformatf("Configuration.Lanenum did not complete within %0d attempts", max_attempts))
endtask : body

`endif
