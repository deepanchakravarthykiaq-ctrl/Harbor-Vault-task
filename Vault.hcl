# Training policy: access only to the sample application secret.
path "secret/data/myapp" {
  capabilities = ["create", "read", "update", "delete"]
}

path "secret/metadata/myapp" {
  capabilities = ["read", "list"]
}
