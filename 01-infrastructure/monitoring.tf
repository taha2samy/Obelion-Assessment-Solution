# ==========================================
# SNS Topic for Alerts
# ==========================================
resource "aws_sns_topic" "alerts" {
  name = "obelion-cpu-high-alerts"
}

# ==========================================
# Email Subscription
# ==========================================
# Note: After applying, you MUST check your email and confirm the subscription
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "samyt8435@gmail.com"
}

# ==========================================
# CloudWatch Alarms
# ==========================================

# 1. Frontend CPU Alarm
resource "aws_cloudwatch_metric_alarm" "frontend_cpu_high" {
  alarm_name          = "frontend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 50
  alarm_description   = "This metric monitors ec2 cpu utilization for Frontend"
  actions_enabled     = true

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.frontend.id
  }
}

# # 2. Backend CPU Alarm
# resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
#   alarm_name          = "backend-cpu-high"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = 2
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = 120
#   statistic           = "Average"
#   threshold           = 50
#   alarm_description   = "This metric monitors ec2 cpu utilization for Backend"
#   actions_enabled     = true

#   alarm_actions = [aws_sns_topic.alerts.arn]
#   ok_actions    = [aws_sns_topic.alerts.arn]

#   dimensions = {
#     InstanceId = aws_instance.backend.id
#   }
# }
