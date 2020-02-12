variable ssh_public_key {}
variable "big-iq-adminpass" {}
variable "bigip1Regkey" {}
variable "bigip1Hostname" {}
variable "bigipAdminPassword" {}
variable "bigipAdminUser" {}

variable "instance_image_ocid" {
  type = "map"

  default = {
    # See https://docs.us-phoenix-1.oraclecloud.com/images/
    # Oracle-provided image "Oracle-Linux-7.5-2018.10.16-0"
    # us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaaoqj42sokaoh42l76wsyhn3k2beuntrh5maj3gmgmzeyr55zzrwwa"
    #us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaabndyiteovjemfz4im4ycvoxarfzqfjhrw362rchpdl4o5bl5tjcq"
    #
    # Custom Created Instance in OCI region you are deploying to
    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaasycydrvbls6bcgtz7lkytlmhxwrxy2wbkiupmkxfr27q2vsxjoma"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaitzn6tdyjer7jl34h2ujz74jwy5nkbukbh55ekp6oyzwrtfa4zma"
    uk-london-1    = "ocid1.image.oc1.uk-london-1.aaaaaaaa32voyikkkzfxyo4xbdmadc2dmvorfxxgdhpnk6dw64fa3l4jh7wa"
  }
}

variable "instanceShape" {
  default = "VM.Standard2.1"
}

resource "oci_core_instance" "bigip1" {
  availability_domain = "${data.oci_identity_availability_domain.ad.name}"
  compartment_id = "${var.compartment_ocid}"
  display_name = "${var.bigip1Hostname}"
  #image = "${var.image}"
  shape = "${var.instanceShape}"
  source_details {
    source_type = "image"
    source_id   = "${var.instance_image_ocid[var.region]}"
  }
  create_vnic_details {
    subnet_id        = "${oci_core_subnet.test_subnet.id}"
    display_name     = "Primaryvnic"
    assign_public_ip = true
    hostname_label   = "bigip1"
  }
  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
  }  
  timeouts {
    create = "60m"
  }
}

resource "oci_core_vnic_attachment" "bigip1_secondary_vnic" {
  instance_id  = "${oci_core_instance.bigip1.id}"
  display_name = "secondaryVnicAttachment"

  create_vnic_details {
    assign_public_ip       = false
    display_name           = "BIGIPSecondaryVnic"
    skip_source_dest_check = true
    subnet_id              = "${oci_core_subnet.data_subnet.id}"
  }
}

output "VE1PrimaryIPAddresses" {
  value = ["${oci_core_instance.bigip1.public_ip}",
           "${oci_core_instance.bigip1.private_ip}"
          ]
}

data "template_file" "onboard" {
  depends_on = ["oci_core_instance.bigip1"]
  template = "${file("${path.module}/onboard.json.tmpl")}"
  vars = {
    targetIP = "${oci_core_instance.bigip1.public_ip}"
    regkey = "${var.bigip1Regkey}"
    hostName = "${var.bigip1Hostname}"
    dataSelfIp = "10.1.30.2"
    bigipPass = "${var.bigipAdminPassword}"
    bigipAdmin = "${var.bigipAdminUser}"
  }
}

resource "local_file" "onboardTemplate" {
  content  = "${data.template_file.onboard.rendered}"
  filename = "${path.module}/onboard.json"
}

resource "null_resource" "bigipDO" {
  depends_on = ["oci_core_instance.bigip1"]

  provisioner "local-exec" {
    command = <<EOC
	curl -u admin:${var.big-iq-adminpass} \
	-k -X POST https://localhost/mgmt/shared/declarative-onboarding \
	-d "@onboard.json"
  EOC
  }
}
