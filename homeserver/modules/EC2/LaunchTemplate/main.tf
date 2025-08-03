resource "aws_launch_template" "launch_template" {
  name_prefix            = var.name_prefix
  image_id               = var.image_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  user_data              = base64encode(var.user_data)
  vpc_security_group_ids = var.security_group_ids
  update_default_version = true

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  hibernation_options {
    configured = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.instance_name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = var.instance_name
    }
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = {
      Name = var.instance_name
    }
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.volume_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}
