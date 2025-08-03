resource "aws_autoscaling_group" "autoscaling_group_template" {
  name_prefix         = var.asg_name
  desired_capacity    = var.asg_desired_capacity
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  vpc_zone_identifier = var.asg_subnet_ids
  target_group_arns   = var.asg_target_group_arns
  health_check_type   = var.asg_health_check_type

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

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.asg_name}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group_template.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.asg_name}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group_template.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.asg_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 50
  alarm_description   = "Scale up if CPU > 50% for 2 minutes"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group_template.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.asg_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "Scale down if CPU < 10% for 2 minutes"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group_template.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}
