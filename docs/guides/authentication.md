# Authentication

Crussh supports multiple SSH authentication methods. This guide covers how to configure them and common patterns.

## Basics

Authentication is configured with the `authenticate` method on your server class.

The block receives credentials and returns a result. The simplest form is just returning truthy or falsy:

```ruby
authenticate(:password) do |username, password|
  Users.authenticate?(username, password)
end
```

For more control and clarity, use the explicit result methods:

### `accept`

Authentication succeeded. The client is granted access.

```ruby
authenticate(:publickey) do |username, key|
  if valid_key?(username, key)
    accept
  else
    reject
  end
end
```

### `reject`

Authentication failed. The client can try again (until `max_auth_attempts`).

```ruby
authenticate(:password) do |username, password|
  unless User.exists?(username)
    reject
  end

  if User.authenticate?(username, password)
    accept
  else
    reject
  end
end
```

### `partial`

Authentication partially succeeded. The client must continue with additional methods. Useful for multi-factor authentication:

```ruby
authenticate(:password) do |username, password|
  user = User.authenticate(username, password)
  next reject unless user

  if user.two_factor_enabled?
    partial :keyboard_interactive # Require 2FA next
  else
    accept
  end
end

authenticate(:keyboard_interactive) do |username, responses|
  Totp.verify(username, responses.first) ? accept : reject
end
```

> **Note:** `partial` requires `keyboard_interactive` which is not yet implemented. This is shown for future reference.

### Summary

| Method                  | Effect                          |
| ----------------------- | ------------------------------- |
| `accept`                | Grant access                    |
| `reject(message = nil)` | Deny, allow retry               |
| `partial(*methods)`     | Require additional auth methods |
| `true` / truthy         | Same as `accept`                |
| `false` / falsy         | Same as `reject`                |

## Authentication Methods

### None

The `none` method is typically used for guest access or as a probe (clients often send `none` first to discover what methods are available).

```ruby
authenticate(:none) do |username|
  username == "guest"
end
```

### Password

Traditional, good ol' username/password authentication:

```ruby
authenticate(:password) do |username, password|
  Users.authenticate(username, password)
end
```

> **Security note:** Password auth is susceptible to brute-force attacks. Consider using `auth_rejection_time` to slow down attempts, and prefer public key authentication when possible.

### Public Key

The most secure and common method. The client proves ownership of a private key:

```ruby
authenticate(:publickey) do |username, key|
  AuthorizedKeys.include?(username, key.fingerprint)
end
```

The `key` parameter is a `Crussh::Keys::PublicKey` with these methods:

| Method              | Description                                   |
| ------------------- | --------------------------------------------- |
| `fingerprint`       | SHA256 fingerprint (e.g., `SHA256:abc123...`) |
| `algorithm`         | Key type (`ssh-ed25519`, `ssh-rsa`, etc.)     |
| `to_authorized_key` | OpenSSH authorized_keys format                |

#### Checking Against authorized_keys

```ruby
authenticate(:publickey) do |username, key|
  path = File.expand_path("~#{username}/.ssh/authorized_keys")
  next false unless File.exist?(path)

  authorized = File.readlines(path).map(&:strip)
  authorized.include?(key.to_authorized_key)
end
```

#### Checking Against a Database

```ruby
authenticate(:publickey) do |username, key|
  user = User.find_by(username: username)
  next false unless user

  user.ssh_keys.any? { |k| k.fingerprint == key.fingerprint }
end
```

## Multiple Methods

You can enable multiple authentication methods. Clients will try them in order based on their configuration:

```ruby
class MyServer < Crussh::Server
  # Guest access
  authenticate(:none) do |username|
    username == "guest"
  end

  # Regular users with keys
  authenticate(:publickey) do |username, key|
    User.find_by(username: username)&.key?(key.fingerprint)
  end

  # Fallback to password
  authenticate(:password) do |username, password|
    User.authenticate(username, password)
  end
end
```

## Banners

Display a message before authentication with `banner`:

```ruby
class MyServer < Crussh::Server
  # Static banner
  banner "Welcome to MyApp!\nUnauthorized access prohibited.\n\n"

  # Dynamic banner
  banner do
    "Welcome! Server time: #{Time.now}\n\n"
  end
end
```

Banners are displayed by the SSH client before the password/key prompt.

## What's Not Supported (Yet)

### Keyboard-Interactive

`keyboard-interactive` authentication (used for 2FA, TOTP, challenge-response) is planned but not yet implemented. PRs welcome!

When implemented, it will look something like:

```ruby
# Future API (not yet available)
authenticate(:keyboard_interactive) do |username, responses|
  # responses is an array of user inputs
  Totp.verify(username, responses.first)
end
```

### Certificates

Now that users can authenticate, you need handlers to process their requests:

**Next**: [Handlers](handlers.md) — Processing shell, exec, and subsystem requests
