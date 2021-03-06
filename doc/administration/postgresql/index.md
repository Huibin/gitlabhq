---
type: reference
---

# Configuring PostgreSQL for scaling

In this section, you'll be guided through configuring a PostgreSQL database to
be used with GitLab in one of our [Scalable and Highly Available Setups](../reference_architectures/index.md).
There are essentially three setups to choose from.

## PostgreSQL replication and failover with Omnibus GitLab **(PREMIUM ONLY)**

This setup is for when you have installed GitLab using the
[Omnibus GitLab **Enterprise Edition** (EE) package](https://about.gitlab.com/install/?version=ee).

All the tools that are needed like PostgreSQL, PgBouncer, Patroni, and repmgr are bundled in
the package, so you can it to set up the whole PostgreSQL infrastructure (primary, replica).

[> Read how to set up PostgreSQL replication and failover using Omnibus GitLab](replication_and_failover.md)

## Standalone PostgreSQL using Omnibus GitLab **(CORE ONLY)**

This setup is for when you have installed the
[Omnibus GitLab packages](https://about.gitlab.com/install/) (CE or EE),
to use the bundled PostgreSQL having only its service enabled.

[> Read how to set up a standalone PostgreSQL instance using Omnibus GitLab](standalone.md)

## Provide your own PostgreSQL instance **(CORE ONLY)**

This setup is for when you have installed GitLab using the
[Omnibus GitLab packages](https://about.gitlab.com/install/) (CE or EE),
or installed it [from source](../../install/installation.md), but you want to use
your own external PostgreSQL server.

[> Read how to set up an external PostgreSQL instance](external.md)
