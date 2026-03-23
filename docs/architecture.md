# Digital Badges Architecture

_A Proof of Concept (PoC) infrastructure plan for nationwide issuing of Scottish digital badges_

## Purpose

This proof of concept tests whether open-source digital badge tools, issuing standards-based verifiable credentials, can serve Scotland’s Youth Awards Network and provide an operational model that could support a wider deployment. The approach is vendor-neutral: open-source components from the [Digital Credentials Consortium](https://github.com/digitalcredentials) (MIT-licensed), configured for Scottish requirements and interoperable with holder wallets using open standards and recommended interoperability profiles.

For credential format, proofs, and exchange conventions, see [Standards and interoperability profile](./standards.md).

## Planned software (selected for first deployment)

The following components form the initial server-side footprint for the PoC:

### DCC Transaction Service

Standards-facing credential exchange (VCALM-oriented flows): issuance, verification, and DID authentication with digital wallets.

### DCC Signing Service

Signs credentials and supplies data-integrity proofs (and status/revocation behaviour as implemented). Used only by the Transaction Service—**not** exposed as a separate public site.

### ORCA (Skybridge Skills)

Staff workflows (invitations to claim awards) and learner experiences: claim and credential management, optional sharing (including social channels where enabled), and flows that move credentials into the DCC Learner Credential Wallet (LCW).

### nginx

Reverse proxy: routes hostnames to the right service, concentrates public ingress, and terminates TLS (TLS 1.2+) for browser and wallet traffic at this tier.

These services are intended to run as containers on a Docker Compose network, so they share a private network namespace while nginx remains the controlled entry point from the internet. In a production deployment, these services could be run as load-balanced horizontally scalable tasks behind an application load balancer and internet gateway.

```{=latex}
\newpage
```

## Deployment overview

```text
[ Browsers / staff / learners ]     [ LCW on devices ]
              |                              |
              v                              v
        TLS at nginx  <----------------------- (HTTPS to api.*)
              |
    +---------+---------+-------------------------+
    |                   |                         |
    v                   v                         v
 ORCA              Transaction Service     (future: VerifierPlus,
 (apex host)       (api subdomain)          OIDF registry on
    |                   |                  reserved subdomains)
    |                   +----> Signing Service (internal only)
    +---- coordinates / uses Transaction Service for exchange flows
```

## Alternatives and ecosystem review

The deployment overview above shows the minimal Compose boundary and how traffic reaches ORCA, the Transaction Service, and the internal Signing Service. This section widens the lens to the rest of the [Digital Credentials Consortium](https://github.com/digitalcredentials) stack and adjacent software: what is scheduled for later, what earlier pilots set aside in favour of ORCA or a consolidated Transaction Service, and what stays essential but outside this compose file (notably the holder wallet). It supports stakeholder transparency and design traceability without repeating the planned software summaries above. Judgements below draw on related pilot work as well as this PoC’s scope.

### Mobile software

#### Learner Credential Wallet

The [Learner Credential Wallet](https://lcw.app) is a mobile app from the DCC that may be used by learners to claim their badges into self-managed custody. Though learners may see all their badges together in the ORCA claim page, LCW is the primary wallet planned for the project.

### Roadmap and deferred

#### VerifierPlus

VerifierPlus provides public verification tooling and share-link style flows for learners. The reference implementation is at https://verifierplus.org and the LCW is hard-coded to that address. As we are not creating our own version of the LCW for this pilot project, any badge issued will use https://verifierplus.org for verification. For this PoC we will prioritise a stable issuance and claim path first and treat creating our own instance of VerifierPlus as a follow-on installation after the core stack is stable, with a draft hostname reserved at `verifier.digitalbadges.scot` when we expose it behind the same nginx ingress pattern. 

#### Self-hosted OIDF issuer registry

An OpenID Federations (OIDF) compatible issuer registry is the production-oriented pattern when Scotland needs an authoritative, self-hosted place for issuer discovery and governance-linked trust decisions. Running that registry early does not by itself make the Learner Credential Wallet trust Scottish issuers: wallets must be configured to use that registry. For the PoC we rely on the DCC Community Registry, a public registry already integrated with the wallet, so pilots can proceed without a bespoke wallet deployment. We still document `registry.digitalbadges.scot` as an example future home for a self-hosted registry demonstration and production path. When a production registry exists and wallet integration is in place, holders will resolve issuers through that trust layer; until then, capability and wallet behaviour should be described separately.

### Superseded or not selected

#### Workflow Coordinator (`workflow-coordinator`)

The DCC Workflow Coordinator previously sat between operator tooling and the Transaction Service, mediating parts of the wallet interaction. That split added an extra HTTP proxy layer without enough benefit: authentication and issuance steps of the exchange are now handled inside the Transaction Service, which we found more performant and reliable than routing those steps through a separate coordinator.

#### DCC Admin Dashboard (`dcc-admin-dashboard`)

The DCC Admin Dashboard targets staff workflows (e.g. inviting learners by email from spreadsheet batch uploads), credential templates, and staff authentication. In evaluation, critical security and maintainability issues led us not to deploy it for this programme. Reported problems included severe authorization defects (including cases where one user could set another user’s password and obtain access under that other user’s account), UX defects (e.g. the application closing when using sidebar navigation on first use), and platform risk: dependence on an outdated Payload CMS 1.x stack that could not be upgraded to 3.x because of dependencies on interface patterns no longer supported, making security fixes and UX improvements disproportionately costly. ORCA (Skybridge Skills’ operator and learner web platform—our cloud service for awards workflows) replaces this dashboard for invitations, templates, and staff-facing administration in the documented architecture.

#### Admin Dashboard Claim Page (`admin-dashboard-claim-page`)

This app provided a learner-facing claim UI tied tightly to the DCC Admin Dashboard, including non-standard extensions to otherwise standard APIs. When the Admin Dashboard was set aside, that claim experience was folded into ORCA for Skybridge-operated deployments, and in open-source-style deployments is addressed through the current Transaction Service and its standards-oriented exchange flows rather than a separate, dashboard-specific claim application.

## PoC Service Configuration

These host names are targets for routing; DNS, certificates, and hardening follow implementation.

**ORCA** Org-specific subdomains `<org>.digitalbadges.scot` — Staff admin, learner claim and credential management, credential registry. Tenant-specific subdomain for each organization and staff.

**DCC Transaction Service** `api.digitalbadges.scot` — Wallet-facing exchange and related APIs.

**VerifierPlus** `verifier.digitalbadges.scot` — Future demo; not in minimal stack.

**OIDF issuer registry** `registry.digitalbadges.scot` — Future self-hosted registry; production trust when wallet integration is ready.

The Signing Service is reachable only on the Docker network (e.g. service hostname internal to Compose), not via a public vhost.

## Trust and holder components (adjacent to Compose)

- DCC Learner Credential Wallet (LCW): cross-platform holder wallet; connects to `api.digitalbadges.scot` for exchange flows.
- DCC Community Registry: pilot trust list already wired into the wallet, reducing PoC friction compared with standing up a new registry and trust programme immediately.
- Production path: self-hosted OIDF registry on `registry.digitalbadges.scot` when Scotland is ready; wallet trust configuration must align before issuers in that registry are treated as trusted by holders’ wallets in the same way as today’s community registry integration.

## API Integration

This section describes how external systems connect for awards, how credential metadata expresses Scottish progression and skills, and how skills frameworks are referenced. Normative credential shapes follow [Open Badges 3.0](https://www.imsglobal.org/spec/ob/v3p0/) (including the data model Achievement and Alignment types).

Provider systems can trigger an invitation to claim a credential for a defined achievement by calling ORCA’s REST API on the tenant host (see PoC hostnames: `https://<org>.digitalbadges.scot`).

### Award endpoint

```http
POST /api/v1/achievements/{achievementId}/award
```

- `achievementId` identifies the Open Badges Achievement (template) to award.
- Request body is JSON:

```json
{
  "email": "user@example.com",
  "narrative": "Markdown description of what they did to earn the badge",
  "evidenceUrl": "https://optional.example.org/evidence-hosted-somewhere"
}
```

| Field         | Purpose                                                                                   |
| ------------- | ----------------------------------------------------------------------------------------- |
| `email`       | Invitee address for the claim workflow.                                                   |
| `narrative`   | Markdown describing what the learner did; flows into assertion/evidence per platform use. |
| `evidenceUrl` | Optional URL for supporting evidence (provider-hosted or other).                          |

### Authentication

Machine clients use OAuth 2.0 client credentials ([RFC 6749 §4.4](https://datatracker.ietf.org/doc/html/rfc6749#section-4.4)) to obtain a short-lived access token (target lifetime one hour, 3600 seconds, consistent with 1EdTech guidance in the Open Badges REST API access token response).

- Obtain `client_id` and `client_secret` out of band (registered for the integrating system).
- Request a token from the `tokenUrl` published in the platform’s service / discovery document for ORCA (same discovery pattern as the [Open Badges 3.0 REST API](https://www.imsglobal.org/spec/ob/v3p0/) security model).
- Use HTTP Basic authentication on the token request with `client_id` and `client_secret`, as specified for the access token exchange in Open Badges API §7.1.2.3 Access Token Request (the `Authorization: Basic …` header pattern).
- Send `application/x-www-form-urlencoded` parameters including `grant_type=client_credentials` and an appropriate `scope` for the awards API (exact scope strings are defined with the deployment).
- Call the award endpoint with `Authorization: Bearer <access_token>` as in Open Badges API §7.1.3 Authenticating with Tokens.

Open Badges API §7.1.2.1 Authorization Request describes the authorization code step (browser redirect + PKCE) for interactive OAuth. That flow is not used for this server-to-server award trigger. The token endpoint URL and client authentication style stay aligned with the Open Badges API; the grant type for these integrations is client credentials.

## Credential metadata (SCQF, skills, and `alignment`)

Open Badges 3.0 Achievement includes an optional `alignment` array: objects that describe which standards or framework nodes the achievement aligns to ([spec: Achievement](https://www.imsglobal.org/spec/ob/v3p0/#achievement)). Each alignment object includes `type` (must include `Alignment`), `targetUrl` (canonical URL for the target node), `targetName`, and optional `targetCode`, `targetFramework`, `targetDescription`, `targetType`, and other defined properties.

We use `alignment` in two ways:

1. Skills and competencies — One or more alignments to published skill or competency URLs (e.g. from a national or international framework). Where a badge is primarily “about” one skill, prefer a single primary skill alignment for clarity; multi-skill badges may list several targets.
2. Scottish Credit and Qualifications Framework (SCQF) — Alignments to official SCQF level definitions so achievements and qualifications are comparable in Scotland. The SCQF helps learners understand and compare qualifications; levels run 1–12 (12 most demanding). Credit points reflect notional learning time (one credit point $\approx$ 10 hours). For achievements that represent a qualification (or equivalent), we select the most authoritative `targetUrl` and `targetCode` for the relevant SCQF level and express that as an `Alignment` entry (with `targetFramework` identifying SCQF as appropriate).

Achievement definitions are authored in ORCA (or migrated from provider data) so issued credentials carry this metadata consistently.

Draft reference values for Open Badges `Alignment` objects when aligning an Achievement to an SCQF level (set `targetFramework` to identify SCQF as appropriate for your deployment).

Use `targetName`, `targetCode`, and `targetUrl` from each level subsection below (descriptor URL is on the line after the body paragraph, separated by a hard line break; or use the plain [level descriptors](https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/) page if `#level-N` fragments do not resolve). For `targetDescription`, use the body paragraph of that subsection (the text before the URL line).

### SCQF targetDescription (draft summaries)

#### SCQF Level 1 (`SCQF-1`)

Recognises learning that ranges from participation in experiential situations to the achievement of basic tasks, with varying degrees of support. Qualifications include: National 1, Awards, Access 1 (discontinued).  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-1`

#### SCQF Level 2 (`SCQF-2`)

Demonstrates basic knowledge and simple facts and ideas. Learners carry out familiar tasks with guidance and use basic tools under supervision. Qualifications include: National 2, Awards, National Certificate, National Progression Award, Access 2 (discontinued).  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-2`

#### SCQF Level 3 (`SCQF-3`)

Demonstrates basic knowledge and simple facts and ideas in a subject/discipline/sector. Learners complete pre-planned tasks and use basic tools with guidance. Qualifications include: National 3, Awards, National Certificate, National Progression Award, Access 3 (discontinued).  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-3`

#### SCQF Level 4 (`SCQF-4`)

Demonstrates basic knowledge and some simple facts and ideas in a subject/discipline/sector, including basic processes, materials and terminology. Learners complete straightforward tasks with some non-routine elements. Qualifications include: National 4, Awards, National Certificate, National Progression Award, SVQ.  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-4`

#### SCQF Level 5 (`SCQF-5`)

Demonstrates basic knowledge and a range of simple facts, ideas and theories in a subject/discipline/sector. Learners plan and organise familiar and unfamiliar tasks. Qualifications include: National 5, Awards, National Certificate, National Progression Award, Modern Apprenticeship, SVQ.  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-5`

#### SCQF Level 6 (`SCQF-6`)

Demonstrates an appreciation of the body of knowledge constituting a subject/discipline/sector. Learners apply knowledge in known practical contexts, including routine and some non-routine elements. Qualifications include: Higher, Awards, National Certificate, National Progression Award, Modern Apprenticeship, Foundation Apprenticeship, SVQ.  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-6`

#### SCQF Level 7 (`SCQF-7`)

Demonstrates an overall appreciation of a subject/discipline/sector, including knowledge embedded in its main theories, concepts and principles. Learners exercise some initiative and independence at a professional level. Qualifications include: Advanced Higher, Scottish Baccalaureate, Higher National Certificate, Certificate of Higher Education, Modern Apprenticeship, SVQ.  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-7`

#### SCQF Level 8 (`SCQF-8`)

Demonstrates knowledge of the scope and defining features of a subject/discipline/sector, including specialist knowledge in some areas. Learners exercise autonomy and initiative in some professional activities. Qualifications include: Higher National Diploma, Diploma of Higher Education, Higher Apprenticeship, Technical Apprenticeship, SVQ.  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-8`

#### SCQF Level 9 (`SCQF-9`)

Demonstrates integrated knowledge of the scope and defining features of a subject/discipline/sector, with critical understanding of principal theories, concepts and terminology. Learners practise in professional level contexts with a degree of unpredictability. Qualifications include: Ordinary degree, Graduate Diploma, Graduate Certificate, Graduate Apprenticeship, Technical Apprenticeship, SVQ.  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-9`

#### SCQF Level 10 (`SCQF-10`)

Demonstrates knowledge covering most principal areas of a subject/discipline/sector, with a critical understanding of principal theories, concepts and principles, and detailed knowledge in one or more specialisms. Learners demonstrate some originality and creativity in dealing with professional issues. Qualifications include: Honours degree, Graduate Diploma, Graduate Certificate, Graduate Apprenticeship, Professional Apprenticeship.  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-10`

#### SCQF Level 11 (`SCQF-11`)

Demonstrates knowledge covering most or all main areas of a subject/discipline/sector, with critical understanding of principal and specialised theories, concepts and principles, and extensive detail in one or more specialisms at or near the forefront. Learners demonstrate leadership and originality in research or development. Qualifications include: Master's degree, Integrated master's degree, Postgraduate Diploma, Postgraduate Certificate, Graduate Apprenticeship, Professional Apprenticeship, SVQ.  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-11`

#### SCQF Level 12 (`SCQF-12`)

Demonstrates a critical overview of a subject/discipline/sector, with leading knowledge and understanding at the forefront of one or more specialisms, generated through personal research making a significant contribution to the field. Learners demonstrate substantial authority, high autonomy, and leadership in professional activities. Qualifications include: Doctorate, Professional Development Award, Professional Apprenticeship.  
`https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-12`

### Example alignment (SCQF Level 5)

```json
{
  "type": "Alignment",
  "targetUrl": "https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/#level-5",
  "targetName": "SCQF Level 5",
  "targetCode": "SCQF-5",
  "targetFramework": "Scottish Credit and Qualifications Framework",
  "targetDescription": "Demonstrates basic knowledge and a range of simple facts, ideas and theories in a subject/discipline/sector. Learners plan and organise familiar and unfamiliar tasks. Qualifications include: National 5, Awards, National Certificate, National Progression Award, Modern Apprenticeship, SVQ."
}
```

**Notes on SCQF Alignment:**

- **targetUrl:** The [level descriptors](https://scqf.org.uk/support/credit-rating-bodies/level-descriptors/) path is the most authoritative per-level reference on the SCQF site; the framework overview page does not offer level-specific anchors. The `#level-N` fragments follow a common deep-linking convention even though the site may use JavaScript-rendered accordions rather than native anchors—verify in a browser before finalising, or use the plain page URL if fragments do not resolve.
- **targetCode:** `SCQF-N` is a compact, unambiguous local convention; SCQF does not publish an official machine-readable code scheme, but this scheme is clear for human viewers, which is the use case for targetCode when an official source does not use unambiguous anchor IDs or URLs for each item in a framework.
- **targetDescription:** Use the paragraph for that level under **SCQF targetDescription (draft summaries)** above. Each paragraph summarises the Knowledge and Understanding descriptor (the most canonical of the five descriptor categories) plus representative qualification types from the framework table—kept short enough for practical use in badge `alignment` without pasting the full official wording.

## Skills frameworks (PoC and org-specific)

For the PoC, ESCO (European Skills, Competences, Qualifications and Occupations) is a practical default: broad coverage and stable public identifiers suitable for `alignment.targetUrl` experiments.

Participating organisations may instead (or additionally) use their own competency or skills frameworks. Where they do, we support publishing that framework so credentials can reference it unambiguously:

- Prefer open, exchange-friendly formats and vocabularies such as CTDL (Credential Transparency Description Language) or CASE (Competency and Academic Standards Exchange), with machine-readable data at a canonical URL used in `targetUrl`.
- Where possible, the same URL should serve a human-readable view for browsers, so staff and learners can follow links from a credential to a meaningful description.
