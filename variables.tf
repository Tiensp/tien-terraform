variable "do_token" {
    description = "DigitalOcean access token"
}

variable "github_token" {
  description = "Github access token"
}

variable "server_ip" {
  description = "IP address of the server"
  type        = string
  default     = output.server_ip
}
