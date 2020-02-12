variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}

variable "compartment_ocid" {}

provider "oci" {
  tenancy_ocid     = "${var.tenancy_ocid}"
  user_ocid        = "${var.user_ocid}"
  fingerprint      = "${var.fingerprint}"
  private_key_path = "${var.private_key_path}"
  region           = "${var.region}"
}

resource "oci_core_vcn" "test_vcn" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "testvcn"
  dns_label      = "testvcn"
}

resource "oci_core_internet_gateway" "test_gw" {
    compartment_id = "${var.compartment_ocid}"
    display_name = "test_vcnIG"
    vcn_id = "${oci_core_vcn.test_vcn.id}"
}

resource "oci_core_route_table" "RouteForComplete" {
#  depends_on = ["oci_core_private_ips.private_ip_datasource"]
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_vcn.test_vcn.id}"
  display_name = "RouteTableForComplete"
  route_rules {
    cidr_block = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.test_gw.id}"
  }
}

resource "oci_core_security_list" "test_vcn" {
  compartment_id = "${var.compartment_ocid}"
  display_name = "Public"
  vcn_id = "${oci_core_vcn.test_vcn.id}"

  // allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol = "6"
  }
  // allow inbound ssh traffic
  ingress_security_rules {
    protocol = "6" // tcp
    source = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 22
      max = 22
    }
  }
  // allow bigip UI Single-NIC management
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      // HTTP traffic
      min = 8443
      max = 8443
    }
  }
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      // HTTP traffic
      min = 443
      max = 443
    }
  }
  ingress_security_rules {
    protocol  = "6"
    source    = "10.1.20.0/24"
    stateless = false
    tcp_options {
      // BIG-IP HA Traffic
      min = 1026
      max = 1026
    }
  }
  ingress_security_rules {
    protocol  = "6"
    source    = "10.1.20.0/24"
    stateless = false
    tcp_options {
      // BIG-IP HA Traffic
      min = 4353
      max = 4353
    }
  }
  ingress_security_rules {
    protocol  = "6"
    source    = "10.1.20.0/24"
    stateless = false
    tcp_options {
      // BIG-IP HA Traffic
      min = 6699
      max = 6699
    }
  }
}

resource "oci_core_subnet" "test_subnet" {
  availability_domain = "${data.oci_identity_availability_domain.ad.name}"
  cidr_block          = "10.1.20.0/24"
  display_name        = "TestSubnet"
  dns_label           = "testsubnet"
  //security_list_ids   = ["${oci_core_vcn.test_vcn.default_security_list_id}"]
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_vcn.test_vcn.id}"
  route_table_id      = "${oci_core_route_table.RouteForComplete.id}"
  dhcp_options_id     = "${oci_core_vcn.test_vcn.default_dhcp_options_id}"
  security_list_ids   = ["${oci_core_security_list.test_vcn.id}"]
}

resource "oci_core_subnet" "data_subnet" {
  availability_domain = "${data.oci_identity_availability_domain.ad.name}"
  cidr_block          = "10.1.30.0/24"
  display_name        = "DataSubnet"
  dns_label           = "datasubnet"
  //security_list_ids   = ["${oci_core_vcn.test_vcn.default_security_list_id}"]
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_vcn.test_vcn.id}"
  route_table_id      = "${oci_core_route_table.RouteForComplete.id}"
  dhcp_options_id     = "${oci_core_vcn.test_vcn.default_dhcp_options_id}"
  security_list_ids   = ["${oci_core_security_list.test_vcn.id}"]
}

data "oci_identity_availability_domain" "ad" {
  compartment_id = "${var.tenancy_ocid}"
  ad_number      = 1
}
