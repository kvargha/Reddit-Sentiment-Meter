variable "region" {
    type = string
    default = "us-west-2"
}

variable "ssh-key-pair-name" {
    type = string
    default = "reddit-producer"
}

variable "ami-id" {
    type = string
    default = "ami-0c65adc9a5c1b5d7c"
}

variable "ec2-instance-type" {
    type = string
    default = "t2.micro"
}