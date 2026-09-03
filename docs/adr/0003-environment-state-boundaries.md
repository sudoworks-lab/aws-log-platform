# ADR 0003: Separate environment roots and state

- Status: Accepted
- Date: 2026-09-03

## Context

Terraform workspaces provide multiple state instances for one configuration, but do not by themselves create strong boundaries for accounts, permissions, lifecycle, review, or accidental command scope.

## Decision

Development and production use separate root configurations under `infra/live/dev` and `infra/live/prod`, separate backend keys, and explicit account inputs. Shared implementation lives in responsibility-based modules.

## Consequences

There is a small, visible amount of composition repetition. In return, backend initialization, credentials, approvals, lifecycle, and blast radius can differ cleanly. Workspaces remain an option for low-risk variations inside one boundary, but not the primary production boundary.

