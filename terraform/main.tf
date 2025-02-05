locals {
  flux_ssh_private_key = try(var.bootstrap_credentials.ssh_private_key_path, null) != null ? file(var.bootstrap_credentials.ssh_private_key_path) : null
  ssh_host             = split("/", split("@", var.system_repo.url)[1])[0]
}

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = var.system_repo.namespace
  }
  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

resource "kubernetes_secret" "flux_sync" {
  metadata {
    name      = var.system_repo.secret
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }
  data = {
    identity       = file(var.flux_credentials.ssh_private_key_path)
    "identity.pub" = file(var.flux_credentials.ssh_public_key_path)
    known_hosts    = data.external.known_hosts.result.key
  }

}

## https://registry.terraform.io/providers/fluxcd/flux/latest/docs/resources/bootstrap_git
resource "flux_bootstrap_git" "main" {
  author_email            = var.bootstrap_credentials.author_email
  author_name             = var.bootstrap_credentials.author_name
  branch                  = var.system_repo.branch
  cluster_domain          = var.flux_properties.cluster_domain
  commit_message_appendix = var.bootstrap_credentials.commit_message
  components              = var.flux_properties.components
  components_extra        = var.flux_properties.components_extra
  image_pull_secret       = var.flux_properties.image_pull_secret
  kustomization_override  = coalesce(var.kustomization_override, file(format("%s/kustomization.yaml", path.root)))
  log_level               = var.flux_properties.log_level
  namespace               = var.system_repo.namespace
  network_policy          = var.flux_properties.network_policy
  path                    = var.system_repo.path == null ? format("flux/clusters/%s", var.aks_cluster_name) : var.system_repo.path
  registry                = var.flux_properties.registry
  secret_name             = "flux-system"
  toleration_keys         = var.flux_properties.toleration_keys
  url                     = var.system_repo.url
  version                 = var.flux_properties.version

  ssh = {
    private_key = local.flux_ssh_private_key
    username    = var.bootstrap_credentials.ssh_username
    password    = var.bootstrap_credentials.ssh_passphrase
  }

  depends_on = [kubernetes_secret.flux_sync]

}
