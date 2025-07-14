enum ServerType { live, test }

class ServerConfig {
  final ServerType type;
  final String name; // e.g., "Live Server", "Test Server"
  final String address; // IP or hostname

  const ServerConfig({
    required this.type,
    required this.name,
    required this.address,
  });
}

// Hardcoded server details
const ServerConfig liveServerConfig = ServerConfig(
  type: ServerType.live,
  name: "Live Server",
  address: "192.168.1.200", // actual live server IP/hostname
);

const ServerConfig testServerConfig = ServerConfig(
  type: ServerType.test,
  name: "Test Server",
  address: "192.168.1.40", // actual test server IP/hostname (default)
);