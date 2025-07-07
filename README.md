# WHK Subdomain Scanner CLI

A powerful and fast command-line subdomain scanner written in Dart.  
Supports DNS brute-force, DNS record extraction (A, AAAA, CNAME, NS, etc.),
DNS over UDP, TCP and DoH protocols, and flexible output formatting.


## Features

- Subdomain brute-force with customizable lengths.
- DNS resolution using UDP, TCP, or DoH (DNS-over-HTTPS).
- Support for multiple DNS record types (A, AAAA, CNAME, TXT, CERT, etc.).
- Uses public DNS resolvers or custom servers.
- Output in JSON mode.
- Parallel asynchronous execution with configurable concurrency.
- Designed for terminal environments (Linux/macOS/WSL).


## Use

```bash
$ wss --help;

WHK Subdomains Scanner.
Usage: wss [options] [methods] [filters] <hostname>

-h, --help       Show this help message.
    --ns         Use a custom name server with uri schema format:
                   [protocol]://[address or hostname]:port/path
                 Supported protocols: udp, tcp, doh.
                 Set path option only for DoH servers.
                 Examples:
                   doh://google.dns:443/dns-query
                   udp://192.168.1.1:53
                   tcp://192.168.1.1:53
                 (defaults to "tcp://8.8.8.8:53")
-o, --out        Save the progress on a json file. By default it generates
                 a random temporary file.
    --brute      [method] Find using brute-force mode using n characters.
    --axfr       [method] Find using a DNS zone transfer query.
    --address    [filter] Resolve the IP address for each subdomain.

Examples:
  wss --ns doh://google.dns:443/dns-query --brute 4 example.com
  wss --ns udp://192.168.1.1:53 --brute 2 example.com
  wss --ns tcp://8.8.8.8:53 --brute 4 --address --out project.json google.com
  wss --ns tcp://nsztm1.digi.ninja:53 --axfr zonetransfer.me
  wss --ns tcp://nsztm1.digi.ninja:53 --axfr --brute 4 zonetransfer.me
```

## Development

Run in develop mode with arguments:

```bash
dart run bin/wss.dart \
    --ns tcp://8.8.8.8:53 --brute 2 --address --out project.json google.com;
```

## Project compilation

Compilation commands:

```bash
dart compile exe --target-os=linux --target-arch=x64 \
    bin/wss.dart -o build/wss-linux-x64;

dart compile exe --target-os=linux --target-arch=arm64 \
    bin/wss.dart -o build/wss-linux-arm64;

dart compile exe --target-os=android --target-arch=arm64 \
    bin/wss.dart -o build/wss-android-arm64;

dart compile exe --target-os=macos --target-arch=x64 \
    bin/wss.dart -o build/wss-macos-x64;

dart compile exe --target-os=windows --target-arch=x64 \
    bin/wss.dart -o build/wss-windows-x64.exe;
```

For more information:
- https://dart.dev/get-dart
- https://dart.dev/tools/dart-compile


## Binaries

You can download binaries from [releases](https://github.com/yhojann-cl/dart-cli-subdomain-scanner/releases).