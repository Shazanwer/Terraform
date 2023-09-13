//]resource "hyperv_network_switch" "dmz_network_switch" {
//]  name = "Default Switch"
//]}

resource "hyperv_network_switch" "zos_network_switch" {
  name                                    = "zosns"
  notes                                   = ""
  allow_management_os                     = true
  enable_embedded_teaming                 = false
  enable_iov                              = false
  enable_packet_direct                    = false
  minimum_bandwidth_mode                  = "None"
  switch_type                             = "Internal"
  net_adapter_names                       = []
  default_flow_minimum_bandwidth_absolute = 0
  default_flow_minimum_bandwidth_weight   = 0
  default_queue_vmmq_enabled              = false
  default_queue_vmmq_queue_pairs          = 16
  default_queue_vrss_enabled              = false
}

resource "hyperv_vhd" "ubuntu_vhd" {
  path = "E:\\Virtual Machines\\Test\\ubuntu.vhdx" #Needs to be absolute path
  size = 10737418240                               #10GB
}

resource "hyperv_machine_instance" "ubuntu" {
  name                   = "ubuntu-test"
  generation             = 1
  processor_count        = 4
  static_memory          = true
  memory_startup_bytes   = 4294967296 #4096MB
  wait_for_state_timeout = 10
  wait_for_ips_timeout   = 10

  vm_processor {
    expose_virtualization_extensions = true
  }

  network_adaptors {
    name         = "zos"
    switch_name  = hyperv_network_switch.zos_network_switch.name
    wait_for_ips = false
  }

  hard_disk_drives {
    controller_type     = "Ide"
    path                = hyperv_vhd.ubuntu_vhd.path
    controller_number   = 0
    controller_location = 0
  }

  dvd_drives {
    controller_number   = 0
    controller_location = 1
    path                = "E:\\Virtual Machines\\ISO\rhel-8.6-x86_64-boot.iso"
  }
}

