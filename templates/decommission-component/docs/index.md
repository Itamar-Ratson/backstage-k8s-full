# Decommission Component Template

This template opens a pull request that deletes the files listed by a scaffolded
component's `backstage.io/source-paths` annotation. It refuses components that
do not carry both the source-paths annotation and the
`backstage.io/managed-by-template` eligibility marker.
