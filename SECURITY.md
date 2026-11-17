# Security Policy

## Supported Versions

Only the latest release on the `main` branch is actively maintained. Older versions do not receive security fixes.

| Version  | Supported |
| :------- | :-------- |
| latest   | ✓         |
| < latest | ✗         |

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Use GitHub's [private vulnerability reporting][private-report] feature to disclose issues confidentially. You will receive an acknowledgment within **5 business days** and a resolution timeline once the report has been triaged.

[private-report]: https://github.com/connect0459/urllib-mbt/security/advisories/new

## Scope

The following vulnerability classes are in scope for this project:

- **Parser crashes** — any input (including malformed, percent-encoded, or adversarially crafted URLs) that causes a panic, SIGSEGV, or unhandled runtime error in `URL.new`, `URL.parse`, or any setter operation.
- **Incorrect parsing results** — silent data corruption or wrong output that violates the [WHATWG URL Standard][url-standard] in a security-relevant way (e.g., origin confusion, incorrect host serialization, or opaque-origin misclassification).
- **URLPattern matching errors** — route-matching logic in `URLPattern` that produces incorrect match/no-match results in ways that could enable authentication bypasses or path-traversal vulnerabilities in applications relying on this library.
- **IDNA processing issues** — incorrect Unicode normalization or punycode conversion that causes domain spoofing or bypasses hostname validation in security-sensitive contexts.

The following are **out of scope**:

- Issues in third-party dependencies (report those upstream).
- Theoretical issues without a reproducible proof-of-concept.
- Behavior that is intentional per the WHATWG URL Standard, even if surprising.

[url-standard]: https://url.spec.whatwg.org/

## Disclosure Policy

Once a fix is ready and released, a GitHub Security Advisory will be published with full details. The typical timeline from report to public disclosure is **30 days**, though this may be extended by mutual agreement when a fix requires significant changes.
