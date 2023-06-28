variable "region" {
    type = string
    default = "us-west-2"
}

variable "root_domain" {
    type = string
    default = "kvargha.com"
}

variable "domain" {
    type = string
    default = "doomermeter.kvargha.com"
}

variable "ssl-cert-arn" {
    type = string
    default = "arn:aws:acm:us-east-1:447400660620:certificate/85f7708a-764d-445b-9938-9de0dcaf61a7"
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

variable "frontend_upload_directory" {
  default = "./frontend/build/"
}

variable "mime_types" {
  default = {
    htm    = "text/html"
    html   = "text/html"
    css    = "text/css"
    ttf    = "font/ttf"
    js     = "application/javascript"
    map    = "application/javascript"
    json   = "application/json"
    txt    = "text/plain"
    xml    = "application/xml"
    pdf    = "application/pdf"
    gif    = "image/gif"
    jpg    = "image/jpeg"
    jpeg   = "image/jpeg"
    png    = "image/png"
    svg    = "image/svg+xml"
    ico    = "image/x-icon"
    mp3    = "audio/mpeg"
    wav    = "audio/wav"
    mp4    = "video/mp4"
    mov    = "video/quicktime"
    avi    = "video/x-msvideo"
    doc    = "application/msword"
    docx   = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    xls    = "application/vnd.ms-excel"
    xlsx   = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    ppt    = "application/vnd.ms-powerpoint"
    pptx   = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    zip    = "application/zip"
    gz     = "application/gzip"
    tar    = "application/x-tar"
    rar    = "application/x-rar-compressed"
    sevenz = "application/x-7z-compressed"
  }
}