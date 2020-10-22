/*
  Description:
  Set up key vault for sap landscape
*/

// Create private KV with access policy
resource "azurerm_key_vault" "kv_prvt" {
  count                      = local.enable_landscape_kv ? 1 : 0
  name                       = local.kv_private_name
  location                   = local.region
  resource_group_name        = local.rg_exists ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  tenant_id                  = local.service_principal.tenant_id
  soft_delete_enabled        = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  sku_name                   = "standard"

  access_policy {
    tenant_id = local.service_principal.tenant_id
    object_id = local.service_principal.object_id

    secret_permissions = [
      "get",
    ]

  }
}

// Create user KV with access policy
resource "azurerm_key_vault" "kv_user" {
  count                      = local.enable_landscape_kv ? 1 : 0
  name                       = local.kv_user_name
  location                   = local.region
  resource_group_name        = local.rg_exists ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  tenant_id                  = local.service_principal.tenant_id
  soft_delete_enabled        = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  sku_name                   = "standard"

  access_policy {
    tenant_id = local.service_principal.tenant_id
    object_id = local.service_principal.object_id

    secret_permissions = [
      "delete",
      "get",
      "list",
      "set",
    ]

  }
}

/* Comment out code with users.object_id for the time being
resource "azurerm_key_vault_access_policy" "kv_user_portal" {
  count        = local.enable_landscape_kv ? length(local.kv_users) : 0
  key_vault_id = azurerm_key_vault.kv_user[0].id
  tenant_id    = data.azurerm_client_config.deployer.tenant_id
  object_id    = local.kv_users[count.index]

  secret_permissions = [
    "delete",
    "get",
    "list",
    "set",
  ]
}
*/
// Using TF tls to generate SSH key pair for iscsi devices and store in user KV
resource "tls_private_key" "iscsi" {
  count = (
    local.enable_landscape_kv && local.enable_iscsi_auth_key
  && try(file(var.sshkey.path_to_public_key), null) == null) ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "azurerm_key_vault_secret" "iscsi_ppk" {
  count        = (local.enable_landscape_kv && local.enable_iscsi_auth_key) ? 1 : 0
  name         = format("%s-iscsi-sshkey", replace(local.prefix,"_","-"))
  value        = local.iscsi_private_key
  key_vault_id = azurerm_key_vault.kv_user[0].id
}

resource "azurerm_key_vault_secret" "iscsi_pk" {
  count        = (local.enable_landscape_kv && local.enable_iscsi_auth_key) ? 1 : 0
  name         = format("%s-iscsi-sshkey-pub", replace(local.prefix,"_","-"))
  value        = local.iscsi_public_key
  key_vault_id = azurerm_key_vault.kv_user[0].id
}

/*
 To force dependency between kv access policy and secrets. Expected behavior:
 https://github.com/terraform-providers/terraform-provider-azurerm/issues/4971
*/
resource "azurerm_key_vault_secret" "iscsi_username" {
  count        = (local.enable_landscape_kv && local.enable_iscsi_auth_password) ? 1 : 0
  name         = format("%s-iscsi-username", replace(local.prefix,"_","-"))
  value        = local.iscsi_auth_username
  key_vault_id = azurerm_key_vault.kv_user[0].id
}

resource "azurerm_key_vault_secret" "iscsi_password" {
  count        = (local.enable_landscape_kv && local.enable_iscsi_auth_password) ? 1 : 0
  name         = format("%s-iscsi-password", replace(local.prefix,"_","-"))
  value        = local.iscsi_auth_password
  key_vault_id = azurerm_key_vault.kv_user[0].id
}

// Generate random password if password is set as authentication type and user doesn't specify a password, and save in KV
resource "random_password" "iscsi_password" {
  count = (
    local.enable_landscape_kv && local.enable_iscsi_auth_password
  && try(local.var_iscsi.authentication.password, null) == null) ? 1 : 0
  length           = 16
  special          = true
  override_special = "_%@"
}

// Using TF tls to generate SSH key pair for SID and store in user KV
resource "tls_private_key" "sid" {
  count     = (local.enable_landscape_kv && try(file(var.sshkey.path_to_public_key), null) == null) ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "azurerm_key_vault_secret" "sid_ppk" {
  count        = local.enable_landscape_kv ? 1 : 0
  name         = format("%s-sid-sshkey", replace(local.prefix,"_","-"))
  value        = local.sid_private_key
  key_vault_id = azurerm_key_vault.kv_user[0].id
}

resource "azurerm_key_vault_secret" "sid_pk" {
  count        = local.enable_landscape_kv ? 1 : 0
  name         = format("%s-sid-sshkey-pub", replace(local.prefix,"_","-"))
  value        = local.sid_public_key
  key_vault_id = azurerm_key_vault.kv_user[0].id
}

// random bytes to product
resource "random_id" "saplandscape" {
  byte_length = 4
}
