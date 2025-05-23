output "instance_id" {
  value = aws_instance.fastapi_server.id
}

output "public_ip" {
  value = aws_eip.ec2_eip.public_ip
}

output "public_dns" {
  value = aws_instance.fastapi_server.public_dns
}
