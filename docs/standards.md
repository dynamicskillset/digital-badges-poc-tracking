# Standards and interoperability profile

Here is a description of the **standards-based interoperability profile** for the Scottish digital badges proof of concept.

## Interoperability profile

The PoC aligns with the **VCALM–EdDSA Open Badges 3.0 interoperability profile** published by the **National Learning Mobility Collaborative** as part of _Digital Credentialing: Issuance, Interoperability, and Verification Guide for Learning Mobility_:

- **Profile:** [VCALM EdDSA Profile](https://interoperability.learningmobilitycollaborative.org/profiles/vcalm-eddsa/)
- **Profile ID (as published):** `vcalm-eddsa-v1`
- **Published profile version / status:** **0.1**, **editor’s draft** (see the profile page for last-updated metadata).

That profile selects concrete options where base specifications allow variation so that **issuers, wallets, and verifiers** can interoperate without pairwise custom integration. **Conformance is not certified** by a third party; the profile itself may **evolve** as drafts mature.

## Standards used

The following list summarises the specifications combined by the VCALM–EdDSA profile. **Authoritative requirements** are on the [profile page](https://interoperability.learningmobilitycollaborative.org/profiles/vcalm-eddsa/); this repository does not duplicate the full requirement set.

- **Open Badges 3.0** — achievement-shaped credentials (`OpenBadgeCredential`), mandatory fields, versioning, expiration as required by the profile.
- **W3C Verifiable Credentials Data Model 2.0** — base credential structure for issuance and verification.
- **W3C Verifiable Credential Data Integrity** — proofs using the **`eddsa-rdfc-2022`** suite, with **`assertionMethod`** proof purpose and requirements for proof metadata (e.g. proof creation time, verification method reference).
- **VCALM Exchanges** (W3C Credentials Community Group draft, e.g. v0.9 as referenced by the profile) — HTTP-based **exchange** for issuance and presentation, including **`vcapi`**, **`QueryByExample`**, **`DIDAuthentication`**, and **Problem Details** style errors where specified.
- **Bitstring Status List** — revocation / status tracking as required by the profile (issuer-bound status lists, verification on acceptance and verification).
- **Decentralized Identifiers (DIDs)** — **`did:web`** and **`did:key`** for issuers and credential subjects, with **Ed25519** verification methods and resolution behaviour as specified.

## Implementation note

Where the standards permit options, this PoC follows the **Digital Credentials Consortium** open-source implementations (Transaction Service, Signing Service, wallet) as deployed in the architecture described in [Architecture](./architecture.md). Any drift between a draft specification and shipping software should be recorded during integration testing.
