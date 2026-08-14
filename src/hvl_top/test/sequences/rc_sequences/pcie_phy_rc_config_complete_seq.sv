`ifndef PCIE_PHY_RC_CONFIG_COMPLETE_SEQ_INCLUDED_
`define PCIE_PHY_RC_CONFIG_COMPLETE_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_config_complete_seq
// Config Complete Seq for the Downstream Port (Root Complex). Steps CFG_COMPLETE -> CFG_IDLE,
// ending at L0_ST once run_configuration_idle() genuinely reports it.
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_config_complete_seq extends uvm_sequence #(pcie_phy_rc_tx);
  `uvm_object_utils(pcie_phy_rc_config_complete_seq)

  pcie_phy_rc_tx req;
  ltssm_state_e final_state;
  int unsigned max_attempts = 10;

  extern function new(string name = "pcie_phy_rc_config_complete_seq");
  extern task body();

endclass : pcie_phy_rc_config_complete_seq

function pcie_phy_rc_config_complete_seq::new(string name = "pcie_phy_rc_config_complete_seq");
  super.new(name);
endfunction : new

task pcie_phy_rc_config_complete_seq::body();
  config_substate_e cur_substate = CFG_COMPLETE;

  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  for (int unsigned attempt = 0; attempt < max_attempts; attempt++) begin
    req = pcie_phy_rc_tx::type_id::create($sformatf("req_%0d", attempt));
    start_item(req);
    if (!req.randomize()) `uvm_error(get_type_name(), "Randomization failed")
    req.is_bfm_verify_item = 1'b0;
    req.task_id = (cur_substate == CFG_COMPLETE) ? LTSSM_TASK_CFG_COMPLETE
                                                   : LTSSM_TASK_CFG_IDLE;
    finish_item(req);

    final_state = req.rsp_state;

    if (final_state == DETECT_ST) begin
      `uvm_error(get_type_name(), "Configuration.Complete/Idle failed - returned to Detect")
      return;
    end

    if (final_state == L0_ST) begin
      `uvm_info(get_type_name(), "Configuration.Idle complete - Link Up (L0)", UVM_LOW)
      return;
    end

    cur_substate = CFG_IDLE; //after Complete, or retrying Idle itself
  end

  `uvm_error(get_type_name(), $sformatf("Configuration.Complete/Idle did not reach L0 within %0d attempts", max_attempts))
endtask : body

`endif
