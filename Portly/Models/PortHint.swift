//
//  PortHint.swift
//  Portly
//

import Foundation

/// Human-friendly guesses for what usually listens on well-known ports.
enum PortHint {
    static let wellKnown: [Int: String] = [
        22: "SSH",
        53: "DNS",
        80: "HTTP",
        443: "HTTPS",
        631: "CUPS printing",
        1025: "Local SMTP",
        1313: "Hugo",
        3000: "Node / Next.js / Rails",
        3001: "Node",
        3306: "MySQL",
        4000: "Jekyll / Phoenix",
        4200: "Angular",
        4321: "Astro",
        5000: "Flask / AirPlay Receiver",
        5173: "Vite",
        5174: "Vite",
        5432: "PostgreSQL",
        5900: "Screen Sharing",
        6006: "Storybook",
        6379: "Redis",
        7000: "AirPlay",
        8000: "Django / Python",
        8025: "Mailpit",
        8080: "HTTP proxy / Tomcat",
        8081: "Metro (React Native)",
        8888: "Jupyter",
        9000: "PHP-FPM / SonarQube",
        9090: "Prometheus",
        9200: "Elasticsearch",
        11211: "Memcached",
        11434: "Ollama",
        19000: "Expo",
        24678: "Vite HMR",
        27017: "MongoDB",
    ]
}
