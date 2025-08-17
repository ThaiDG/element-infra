resource "aws_autoscaling_group" "autoscaling_group_template" {
  name_prefix         = var.asg_name
  desired_capacity    = var.asg_desired_capacity
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  vpc_zone_identifier = var.asg_subnet_ids
  target_group_arns   = var.asg_target_group_arns
  health_check_type   = var.asg_health_check_type
  enabled_metrics     = ["GroupDesiredCapacity"]

  # Since Synapse instance need a little time to warm up
  default_instance_warmup = 500

  launch_template {
    id      = var.launch_template_id
    version = "$Default"
  }

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = var.instance_name
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.asg_name}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group_template.name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_up_tracking" {
  name                   = "${var.asg_name}-scale-up-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group_template.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = 40
    disable_scale_in = true
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low_guarded" {
  alarm_name          = "${var.asg_name}-guarded-cpu-low-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  threshold           = 20
  alarm_description   = "CPU below threshold, only when ASG has ≥1 instance"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "m1"
    label       = "CPUUtilization"
    return_data = false

    metric {
      namespace   = "AWS/AutoScaling"
      metric_name = "CPUUtilization"
      period      = 300
      stat        = "Average"
      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.autoscaling_group_template.name
      }
    }
  }

  metric_query {
    id          = "m2"
    label       = "GroupDesiredCapacity"
    return_data = false

    metric {
      namespace   = "AWS/AutoScaling"
      metric_name = "GroupDesiredCapacity"
      period      = 300
      stat        = "Average"
      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.autoscaling_group_template.name
      }
    }
  }

  metric_query {
    id          = "e1"
    expression  = "IF(m2 > 1, m1, 100)" # If the GroupDesiredCapacity <= 1, set the return value to higher than threshold to avoid triggering the scale down
    label       = "SafeToScaleDownCPU"
    return_data = true
  }

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}
