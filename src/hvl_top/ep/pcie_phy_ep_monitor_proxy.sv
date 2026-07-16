`ifndef PCIE_PHY_EP_MONITOR_PROXY_INCLUDED_
`define PCIE_PHY_EP_MONITOR_PROXY_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_monitor_proxy
// Monitor proxy for the Upstream Port (Endpoint).
// A monitor is a passive entity that samples link signals through the
// virtual pcie_phy_ep_monitor_bfm handle and converts signal-level activity
// into transaction-level items; it cannot drive.
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_monitor_proxy extends uvm_component;
  `uvm_component_utils(pcie_phy_ep_monitor_proxy)

  //Variable: pcie_phy_ep_agent_cfg_h
  pcie_phy_ep_agent_config pcie_phy_ep_agent_cfg_h;

  //Variable: pcie_phy_ep_mon_bfm_h
  virtual pcie_phy_ep_monitor_bfm pcie_phy_ep_mon_bfm_h;

  //Variable: ltssm_state_analysis_port
  uvm_analysis_port #(pcie_phy_ep_tx) ltssm_state_analysis_port;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_ep_monitor_proxy", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_ep_monitor_proxy

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_ep_monitor_proxy
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_ep_monitor_proxy::new(string name = "pcie_phy_ep_monitor_proxy", uvm_component parent = null);
  super.new(name, parent);
  ltssm_state_analysis_port = new("ltssm_state_analysis_port", this);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_monitor_proxy::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db #(virtual pcie_phy_ep_monitor_bfm)::get(this, "", "pcie_phy_ep_monitor_bfm", pcie_phy_ep_mon_bfm_h)) begin
    `uvm_fatal("FATAL_EP_MON_BFM", $sformatf("Couldn't get the ep monitor_bfm handle from config_db"))
  end
  `uvm_info(get_type_name(), "Got the ep monitor_bfm handle from config_db", UVM_LOW)
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_monitor_proxy::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Task: run_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task pcie_phy_ep_monitor_proxy::run_phase(uvm_phase phase);
  forever begin
    // TODO: call pcie_phy_ep_mon_bfm_h.sample_<state>() per current LTSSM state,
    //       build a pcie_phy_ep_tx item, ltssm_state_analysis_port.write(item)
    @(posedge pcie_phy_ep_mon_bfm_h.aclk);
  end
endtask : run_phase


`endif
