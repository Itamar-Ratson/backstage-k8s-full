data "external" "git_remote" {
  program = ["${path.module}/scripts/git-remote.sh"]
}
