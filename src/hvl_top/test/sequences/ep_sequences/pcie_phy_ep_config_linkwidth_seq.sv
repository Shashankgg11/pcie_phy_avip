`ifndef PCIE_PHY_EP_CONFIG_LINKWIDTH_SEQ_INCLUDED_
`define PCIE_PHY_EP_CONFIG_LINKWIDTH_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_config_linkwidth_seq
// Mirrors pcie_phy_rc_config_linkwidth_seq exactly.
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_config_linkwidth_seq extends uvm_sequence #(pcie_phy_ep_tx);
  `uvm_object_utils(pcie_phy_ep_config_linkwidth_seq)

  pcie_phy_ep_tx req;
  ltssm_state_e     final_state;
  config_substate_e final_config_substate;
  int unsigned max_attempts = 10;

  extern function new(string name = "pcie_phy_ep_config_linkwidth_seq");
  extern task body();

endclass : pcie_phy_ep_config_linkwidth_seq

function pcie_phy_ep_config_linkwidth_seq::new(string name = "pcie_phy_ep_config_linkwidth_seq");
  super.new(name);
endfunction : new

task pcie_phy_ep_config_linkwidth_seq::body();
  config_substate_e cur_substate = CFG_LINKWIDTH_START;

  `uvm_info(get_type_name(), $sformatf("Starting %s", get_type_name()), UVM_MEDIUM)

  for (int unsigned attempt = 0; attempt < max_attempts; attempt++) begin
    req = pcie_phy_ep_tx::type_id::create($sformatf("req_%0d", attempt));
    start_item(req);
    if (!req.randomize()) `uvm_error(get_type_name(), "Randomization failed")
    req.is_bfm_verify_item = 1'b0;
    req.task_id = (cur_substate == CFG_LINKWIDTH_START) ? LTSSM_TASK_CFG_LINKWIDTH_START
                                                          : LTSSM_TASK_CFG_LINKWIDTH_ACCEPT;
    finish_item(req);

    final_state           = req.rsp_state;
    final_config_substate = req.rsp_config_substate;

    if (final_state == DETECT_ST) begin
      `uvm_error(get_type_name(), "Configuration.Linkwidth failed - returned to Detect")
      return;
    end

    if (cur_substate == CFG_LINKWIDTH_START) begin
      cur_substate = final_config_substate;
    end
    else begin
      if (final_config_substate == CFG_LANENUM_WAIT) begin
        `uvm_info(get_type_name(), "Configuration.Linkwidth complete - advancing to Lanenum.Wait", UVM_LOW)
        return;
      end
      cur_substate = CFG_LINKWIDTH_START;
    end
  end

  `uvm_error(get_type_name(), $sformatf("Configuration.Linkwidth did not complete within %0d attempts", max_attempts))
endtask : body

`endif
