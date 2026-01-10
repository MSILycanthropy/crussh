# Crussh Documentation

Crussh is a lowish-level SSH server library for Ruby. Build SSH applications — shells, git servers, coffee hops — all without touching OpenSSH.

## Getting Started

- [Getting Started](getting-started.md) — Install Crussh and build your first server

## Guides

- [Configuration](guides/configuration.md) — Server settings, timeouts, limits, and host keys
- [Authentication](guides/authentication.md) — Password, public key, and custom auth flows
- [Handlers](guides/handlers.md) — Processing shell, exec, and subsystem requests
- [Input Handling](guides/input-handling.md) — Reading input at three levels of abstraction
- [Channels](guides/channels.md) — Direct channel access for advanced use cases
- [Logging](guides/logging.md) — Structured logging with automatic filtering
- [Deployment](guides/deployment.md) — systemd, production configuration, and best practices

## Examples

Complete, runnable examples:

- [Echo Server](examples/echo-server.md) — The simplest possible Crussh server
- [Interactive Shell](examples/interactive-shell.md) — Line editing and command dispatch
- [Command Runner](examples/command-runner.md) — Executing system commands via exec
- [TUI Application](examples/tui-app.md) — Building terminal UIs with resize handling

## Links

- [GitHub Repository](https://github.com/MSILycanthropy/crussh)
- [RubyGems](https://rubygems.org/gems/crussh)
- [Changelog](https://github.com/MSILycanthropy/crussh/blob/main/CHANGELOG.md)
