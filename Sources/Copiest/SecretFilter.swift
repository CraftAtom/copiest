import Foundation

/// Recognizes text that looks like a credential, so the history never stores it.
enum SecretFilter {
    /// Common credential formats. Each pattern aims to leave ordinary code and prose
    /// alone, so a secret in an unusual format still gets through.
    static let patterns = [
        #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#,
        #"\bgh[pousr]_[A-Za-z0-9]{36,}"#,  // GitHub
        #"\bgithub_pat_[A-Za-z0-9_]{22,}"#,
        #"\bglpat-[A-Za-z0-9_-]{20,}"#,  // GitLab
        #"\bsk-[A-Za-z0-9_-]{20,}"#,  // OpenAI, Anthropic
        #"\b[sr]k_(live|test)_[A-Za-z0-9]{16,}"#,  // Stripe
        #"\bwhsec_[A-Za-z0-9]{24,}"#,  // Stripe webhook signing secret
        #"\b(AKIA|ASIA)[0-9A-Z]{16}\b"#,  // AWS access key ID
        #"\bxox[abprs]-[A-Za-z0-9-]{10,}"#,  // Slack
        #"hooks\.slack\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[A-Za-z0-9]+"#,
        #"discord(app)?\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+"#,
        #"\bAIza[0-9A-Za-z_-]{35}"#,  // Google API key
        #"\bya29\.[A-Za-z0-9_-]{20,}"#,  // Google OAuth access token
        #"\bSG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}\b"#,  // SendGrid
        #"\bhf_[A-Za-z0-9]{30,}"#,  // Hugging Face
        #"\bdo[por]_v1_[a-f0-9]{64}"#,  // DigitalOcean
        #"\bshp(at|ss|ca|pa)_[a-fA-F0-9]{32}"#,  // Shopify
        #"\bnpm_[A-Za-z0-9]{36}"#,
        #"\bpypi-AgEIcHlwaS5vcmc[A-Za-z0-9_-]{50,}"#,
        #"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#,  // JWT
        // A password inside a URL, such as postgres://user:pass@host.
        #"\b[a-zA-Z][a-zA-Z0-9+.-]{0,20}://[^\s/:@]+:[^\s/@]+@"#,
        // An Authorization header value.
        #"(?i)\b(bearer|basic)[ \t]+[A-Za-z0-9._~+/=-]{16,}"#,
        // Shell and .env lines such as `export API_TOKEN=...`. The name must end with the
        // keyword and the value must be 8 characters or more and not only digits, so
        // `MAX_TOKENS = 100000` and `TOKEN_TYPE = "Bearer"` are still recorded.
        #"(?m)^[ \t]*(export[ \t]+)?[A-Z0-9_]*(SECRET|TOKEN|PASSWORD|PASSWD|PWD|API_?KEY|PRIVATE_?KEY|ACCESS_?KEY|CREDENTIALS?)S?[ \t]*=[ \t]*["']?(?![0-9]+\b)[^\s"']{8,}"#,
        // Quoted values in JSON, YAML, and code, such as "db_password": "hunter22".
        #"(?i)[A-Za-z0-9_.-]*(password|passwd|secret|api_?key|apikey|token|access_?key|private_?key)s?["']?[ \t]*[:=][ \t]*["'](?![0-9]+["'])[^"'\s]{8,}["']"#,
        // Unquoted YAML values such as `password: hunter22` on a line of their own.
        // Code such as `token: getToken(),` doesn't match because of the brackets and comma.
        #"(?im)^[ \t]*[A-Za-z0-9_.-]*(password|passwd|secret|api_?key|apikey|token|access_?key|private_?key)s?[ \t]*:[ \t]+(?![0-9]+[ \t]*$)[^\s"'#(){}\[\],;$]{8,}[ \t]*$"#,
        // Command-line flags such as --password=hunter22 or --api-key hunter22.
        #"(?i)(^|\s)--?[A-Za-z-]*(password|passwd|secret|token|api-?key)[ \t]*[= \t][ \t]*["']?[^\s"'-][^\s"']{5,}"#,
    ]

    /// Compiled once, because the filter runs on every copy.
    private static let regexes = patterns.map { try! NSRegularExpression(pattern: $0) }

    static func looksSecret(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return regexes.contains { $0.firstMatch(in: text, range: range) != nil }
    }

    /// Text that must be caught, and text that must be kept. `--selftest` checks both.
    static let selftestSecrets = [
        "ghp_" + String(repeating: "a1B2", count: 9),
        "sk-ant-api03-" + String(repeating: "x", count: 30),
        "sk_live_" + String(repeating: "4eC3", count: 6),
        "whsec_" + String(repeating: "Ab12", count: 8),
        "AKIAIOSFODNN7EXAMPLE",
        "SG." + String(repeating: "a", count: 22) + "." + String(repeating: "b", count: 43),
        "hf_" + String(repeating: "Xy9", count: 12),
        "ya29." + String(repeating: "a0B", count: 10),
        "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U",
        "postgresql://app:hunter22@db.example.com:5432/app",
        "export DATABASE_PASSWORD='hunter22'",
        "OPENAI_API_KEY=abc123def456",
        "AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        #"{"password": "hunter22"}"#,
        #"{"db_password": "hunter22"}"#,
        #"const password = "hunter22hunter""#,
        "password: hunter22",
        "  aws_secret: abcdEFGH1234",
        "Authorization: Bearer abcdefghijklmnop1234",
        "mysql --password=hunter22 -u root",
        "cli login --api-key abcdef123456",
        "-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXk=",
    ]
    static let selftestKeep = [
        "hello world",
        "https://github.com/CraftAtom/zombieport",
        "git@github.com:CraftAtom/zombieport.git",
        "const token = getToken()",
        "  token: getToken(),",
        "password: see the team vault",
        "scikit-learn and sk-learn",
        "67BDD922-9C05-4944-AB48-AF47CE627420",
        "PORT=3000",
        "MAX_TOKENS = 100000",
        "MAX_TOKENS = 1000000000",
        #"TOKEN_TYPE = "Bearer""#,
        "tokenizer: whitespace_tokenizer",
        "max_tokens: 4096",
        "Bearer tokens are basic auth's cousin",
        "./run --token-file ./secrets/token.txt",
        #"{"tokens": 1234567890}"#,
    ]
}
