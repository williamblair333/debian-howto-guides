# CODEX

A technical reference repository for applied service integration.  
Focus: interoperability, API behavior, credential handling, workflow execution, and failure patterns.

This repository exists to preserve operational knowledge that required investigation, debugging, or reverse-engineering to obtain.

---

## Purpose

CODEX captures implementation-grade integration procedures so that solved problems do not need to be re-solved.

Content here answers questions of the form:

- How is this API actually called in practice?
- What breaks in real deployments?
- What credentials, headers, or formats are required?
- What error patterns occur and how are they resolved?
- What does a working configuration look like?


---

## Scope

Included:

- API integration procedures  
- Authentication and credential configuration  
- Webhook ingestion patterns  
- Service-to-service communication  
- Workflow engine integrations (e.g., n8n, custom services, agent systems)  
- Observed failure modes and their remedies  
- Minimal, reproducible configuration examples  

Every document must enable direct execution or prevent a known integration failure.

---

## Explicit Exclusions

The following do not belong in CODEX:

- Framework documentation  
- Project-specific operational runbooks  
- Architectural essays or design philosophy  
- Educational theory or conceptual introductions  
- Opinion pieces or narrative commentary  
- Marketing language  

If material does not improve reproducibility or reduce integration friction, it is out of scope.

---

## Document Standard

Each guide must include:

1. **Objective** — the exact integration result achieved  
2. **Inputs** — credentials, tokens, endpoints, or prerequisites  
3. **Procedure** — deterministic steps  
4. **Verification** — observable success condition  
5. **Failure Patterns** — common errors and their resolution  
6. **Security Notes** — exposure risks and handling constraints  

A document that cannot be executed by a technically competent reader is incomplete.

---

## Contribution Rule

Only record knowledge that meets at least one of the following:

- Required non-obvious configuration  
- Produced misleading or undocumented errors  
- Required synthesis of multiple sources  
- Contradicted official documentation  
- Exposed a system limitation or constraint  

CODEX is a compression of integration experience.

---

## Writing Standard

Language must be:

- Precise  
- Unambiguous  
- Operational  
- Free of rhetorical or motivational phrasing  

Explanations are acceptable only when necessary to enable execution or prevent failure.

---

## License

**GNU Affero General Public License v3.0 (AGPL-3.0)**

Rationale:

- Derivative work must remain open  
- Modifications used in hosted services must be disclosed  
- Prevents privatization of integration knowledge  

See `LICENSE` file for full terms.
