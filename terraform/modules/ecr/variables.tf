variable "name" {
  description = "Name of the ECR repository (e.g. ecs-project/olaolat)"
  type        = string
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten. MUTABLE or IMMUTABLE"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Whether images are scanned for vulnerabilities on push"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type for the repository. AES256 or KMS"
  type        = string
  default     = "AES256"
}

variable "kms_key" {
  description = "ARN of the KMS key to use when encryption_type is KMS (null uses the default AWS-managed key)"
  type        = string
  default     = null
}

variable "force_delete" {
  description = "Whether to delete the repository even if it still contains images"
  type        = bool
  default     = false
}

variable "max_image_count" {
  description = "Number of most-recent images to retain; older ones are expired by a lifecycle policy. Set to 0 to disable the lifecycle policy"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags applied to the repository"
  type        = map(string)
  default     = {}
}
