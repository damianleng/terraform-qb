variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "force_destroy" {
  description = "Allow bucket deletion even if not empty"
  type        = bool
  default     = false
}
