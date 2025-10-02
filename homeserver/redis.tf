# LIVEKIT REDIS/VALKEY CACHE (DISABLED)
# Create Security Group to allow Access Redis
# resource "aws_security_group" "valkey" {
#   name        = "${var.workspace}-valkey-serverless-sg"
#   description = "Security group for Valkey Serverless Redis"
#   vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

#   ingress {
#     description = "Allow Redis client traffic"
#     from_port   = 6379
#     to_port     = 6379
#     protocol    = "tcp"
#     # Adjust this CIDR or security group reference to match your app tier
#     cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# # Create Valkey serverless cluster
# resource "aws_elasticache_serverless_cache" "livekit" {
#   name               = "${var.workspace}-livekit-valkey"
#   engine             = "valkey"
#   description        = "LiveKit Valkey Serverless Cache"
#   security_group_ids = [aws_security_group.valkey.id]
#   subnet_ids         = data.terraform_remote_state.vpc.outputs.private_subnet_ids

#   # Serverless capacity bounds (GiB). Adjust to your workload.
#   cache_usage_limits {
#     data_storage {
#       minimum = 1.0
#       maximum = 2.0
#       unit    = "GB"
#     }
#     ecpu_per_second {
#       minimum = 1000
#       maximum = 2000
#     }
#   }

#   tags = {
#     Name = "${var.workspace}-livekit-valkey-serverless"
#   }
# }
