# Configuration

Crussh servers are configured using the `configure` block. This guide covers all available options.

## Basic Configuration

```ruby
class MyServer < Crussh::Server
  configure do |c|
    c.host = "0.0.0.0"
    c.port = 2222
    c.generate_host_keys!
  end
end
```

## Network

`host`

The address to bind to.

```ruby
c.host = "0.0.0.0"      # All interfaces (default: "127.0.0.1")
c.host = "127.0.0.1"    # Localhost only
c.host = "192.168.1.10" # Specific interface
```

`port`

The port to listen on.

```ruby
c.port = 22    # Standard SSH port (requires root)
c.port = 2222  # Development port (default: 22)
```

`nodelay`

Enable TCP_NODELAY (disable Nagle's algorithm) for lower latency.

```ruby
c.nodelay = true # Default: false
```

## Host Keys

Every SSH server needs at least one host key. Clients use this to verify they're connecting to the right server.

`generate_host_keys!`

Generate an Ed25519 key automatically. Good for development:

```ruby
c.generate_host_keys!
```

The key is generated in memory and won't persist across restarts. Clients will see a new host key each time, which triggers warnings.

`host_key_files`

Load keys from files. Use this in production:

```ruby
c.host_key_files << "/etc/crussh/ssh_host_ed25519_key"
c.host_key_files << "/etc/crussh/ssh_host_rsa_key"
```

Generate keys with:

```bash
ssh-keygen -t ed25519 -f /etc/crussh/ssh_host_ed25519_key -N ""
ssh-keygen -t rsa -b 4096 -f /etc/crussh/ssh_host_rsa_key -N ""
```

`host_keys`

Add key objects directly:

```ruby
key = Crussh::Keys.generate(:ed25519)
c.host_keys << key

# Or load from a string
key_data = File.read("/path/to/key")
c.host_keys << Crussh::Keys.from_openssh(key_data)
```

## Connection Limits

`max_connections`

Maximum total concurrent connections.

```ruby
c.max_connections = 100 # Default: nil (unlimited)
```

`max_unauthenticated`

Maximum connections that haven't completed authentication yet. Helps prevent resource exhaustion from slow or malicious clients.

```ruby
c.max_unauthenticated = 20 # Default: nil (unlimited)
```

`max_auth_attempts`

Maximum authentication attempts per connection before disconnecting.

```ruby
c.max_auth_attempts = 6 # Default: 6
```

## Timeouts

`connection_timeout`

Seconds to wait for initial connection setup (version exchange, key exchange).

```ruby
c.connection_timeout = 10 # Default: 10
```

`auth_timeout`

Seconds to wait for authentication to complete. If `nil`, falls back to `connection_timeout`.

```ruby
c.auth_timeout = 30 # Default: nil
```

`inactivity_timeout`

Seconds of inactivity before disconnecting. Measured from the last received packet.

```ruby
c.inactivity_timeout = 600 # Default: nil (no timeout)
```

## Keepalive

SSH keepalives detect dead connections and keep NAT mappings alive.

`keepalive_interval`

Seconds between keepalive requests. Set to `nil` to disable.

```ruby
c.keepalive_interval = 30 # Default: nil (disabled)
```

`keepalive_max`

Maximum missed keepalive responses before disconnecting.

```ruby
c.keepalive_max = 3 # Default: 3
```

## Channels

`window_size`

Initial flow control window size in bytes. Larger values allow more data in flight but use more memory.

```ruby
c.window_size = 2 * 1024 * 1024 # Default: 2MB
```

`max_packet_size`

Maximum packet size in bytes. Must be between 1024 and 262144.

```ruby
c.max_packet_size = 32_768 # Default: 32KB
```

## Authentication Timing

`auth_rejection_time`

Seconds to wait before sending an auth failure response. Slows down brute-force attacks.

```ruby
c.auth_rejection_time = 1 # Default: 1
```

`auth_rejection_time_initial`

Seconds to wait on the first auth attempt (typically a `none` probe). Set to `nil` to use `auth_rejection_time`.

```ruby
c.auth_rejection_time_initial = 0 # Default: nil
```

## Server Identity

`server_id`

The SSH identification string sent to clients. Appears in SSH debug output.

```ruby
c.server_id = Crussh::SshId.new("MyApp_1.0") # Default: "Crussh_{version}"
```

## Algorithm Preferences

`preferred`

Configure algorithm preferences. Algorithms are tried in order:

```ruby
c.preferred.kex = [
  Crussh::Kex::CURVE25519_SHA256,
  Crussh::Kex::CURVE25519_SHA256_LIBSSH,
]

c.preferred.host_key = [
  Crussh::Keys::ED25519,
  Crussh::Keys::RSA_SHA512,
]

c.preferred.cipher = [
  Crussh::Cipher::CHACHA20_POLY1305,
]

c.preferred.mac = [
  Crussh::Mac::HMAC_SHA512_ETM,
  Crussh::Mac::HMAC_SHA256_ETM,
]

c.preferred.compression = [
  Crussh::Compression::ZLIB,
  Crussh::Compression::NONE,
]
```

## Rekey Limits

The SSH connection will automatically rekey after certain thresholds to limit exposure of any single key.

`limits.rekey_write_limit`

Bytes written before rekeying.

```ruby
c.limits.rekey_write_limit = 1 << 30 # Default: 1GB
```

`limits.rekey_read_limit`

Bytes read before rekeying.

```ruby
c.limits.rekey_read_limit = 1 << 30 # Default: 1GB
```

`limits.rekey_time_limit`

Seconds before rekeying.

```ruby
c.limits.rekey_time_limit = 3600 # Default: 1 hour
```

## Full Example

```ruby
class ProductionServer < Crussh::Server
  configure do |c|
    # Network
    c.host = "0.0.0.0"
    c.port = 22
    c.nodelay = true

    # Host keys (persistent)
    c.host_key_files << "/etc/myapp/ssh_host_ed25519_key"

    # Limits
    c.max_connections = 500
    c.max_unauthenticated = 50
    c.max_auth_attempts = 3

    # Timeouts
    c.connection_timeout = 10
    c.auth_timeout = 30
    c.inactivity_timeout = 1800 # 30 minutes

    # Keepalive
    c.keepalive_interval = 60
    c.keepalive_max = 3

    # Slow down brute force
    c.auth_rejection_time = 2
    c.auth_rejection_time_initial = 0

    # Identity
    c.server_id = Crussh::SshId.new("MyApp_1.0")
  end
end
```

## Inheritance

Server configuration is inherited by subclasses:

```ruby
class BaseServer < Crussh::Server
  configure do |c|
    c.max_connections = 100
    c.keepalive_interval = 30
  end
end

class DevServer < BaseServer
  configure do |c|
    c.port = 2222
    c.generate_host_keys!
  end
end

class ProdServer < BaseServer
  configure do |c|
    c.port = 22
    c.host_key_files << "/etc/myapp/host_key"
  end
end
```

## Runtime Configuration

You can also pass configuration when instantiating:

```ruby
server = MyServer.new(port: 3333, max_connections: 50)
server.run
```

These override the class-level configuration.

## Next Steps

Now that your server is configured, you'll want to setup Authentication,

**Next**: [Authentication](authentication.md) — Password, public key, and custom auth flows
