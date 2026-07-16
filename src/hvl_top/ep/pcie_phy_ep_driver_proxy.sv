`ifndef PCIE_PHY_EP_DRIVER_PROXY_INCLUDED_
`define PCIE_PHY_EP_DRIVER_PROXY_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_ep_driver_proxy
// Driver proxy for the Upstream Port (Endpoint).
// Extends uvm_driver; pulls pcie_phy_ep_tx items from the sequencer and
// drives them via the virtual pcie_phy_ep_driver_bfm handle obtained from config_db.
//--------------------------------------------------------------------------------------------
class pcie_phy_ep_driver_proxy extends uvm_driver #(pcie_phy_ep_tx);
  `uvm_component_utils(pcie_phy_ep_driver_proxy)

  //Variable: pcie_phy_ep_agent_cfg_h
  pcie_phy_ep_agent_config pcie_phy_ep_agent_cfg_h;

  //Variable: pcie_phy_ep_drv_bfm_h
  virtual pcie_phy_ep_driver_bfm pcie_phy_ep_drv_bfm_h;

  //Variable: req
  pcie_phy_ep_tx req;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_ep_driver_proxy", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);

endclass : pcie_phy_ep_driver_proxy

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_ep_driver_proxy
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_ep_driver_proxy::new(string name = "pcie_phy_ep_driver_proxy", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_driver_proxy::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db #(virtual pcie_phy_ep_driver_bfm)::get(this, "", "pcie_phy_ep_driver_bfm", pcie_phy_ep_drv_bfm_h)) begin
    `uvm_fatal("FATAL_EP_DRV_BFM", $sformatf("Couldn't get the ep driver_bfm handle from config_db"))
  end
  `uvm_info(get_type_name(), "Got the ep driver_bfm handle from config_db", UVM_LOW)
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_ep_driver_proxy::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

//--------------------------------------------------------------------------------------------
// Task: run_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task pcie_phy_ep_driver_proxy::run_phase(uvm_phase phase);
  forever begin
    seq_item_port.get_next_item(req);
    // TODO: dispatch to pcie_phy_ep_drv_bfm_h.run_<state>_task(...) based on req.target_state
    seq_item_port.item_done();
  end
endtask : run_phase


`endif
