# Security Architecture

TODO: Refine the content on this page and create an implementation tracking checklist where we can
reference how we are performing each thing. Cleanup the not quite good markdown formatting.

Dynamic Skillset Ltd and Skybridge Skills commit to implementing and maintaining the five technical
controls specified by the Cyber Essentials scheme throughout contract delivery, in accordance with
Procurement Policy Note 09/14 which permits demonstration of equivalent controls through independent
third-party verification.

## The Five Technical Controls

1. Firewalls and Internet Gateways All development and deployment systems protected by configured
   firewalls Planned PoC ingress: public HTTPS terminated at an **nginx** reverse proxy routing to
   application containers (see [Architecture](./architecture.md)) Unnecessary ports closed with
   documented port management
   - The mail service (Postfix) does not publish any host ports; SMTP submission is reachable only
   from other containers on the Compose network. Remote access restricted to authorised IP addresses
   Regular firewall rule audits
2. Secure Configuration Systems configured to security baselines with default passwords changed
   Unnecessary software and services disabled Strong password policies enforced (minimum 12
   characters, complexity requirements) Multi-factor authentication where supported Auto-run and
   auto-execute features disabled
   - ORCA → mail SMTP AUTH travels plaintext over the internal Docker bridge (not over the public
     network). An adversary with sniff capability on the bridge has already compromised the host;
     the tradeoff is accepted for PoC.
3. User Access Control Principle of least privilege applied to all accounts Separate administrator
   accounts used only for elevated tasks Standard user accounts for routine work Regular access
   permission reviews Documented access management procedures
4. Security Update Management Automated operating system updates configured Third-party software
   patching within 14 days of security releases
   - External Docker images in the PoC stack (including `boky/postfix`, `postgres`, `redis`,
   `nginx`, and the DCC services) are pinned by tag and where feasible by digest; security updates
   to upstream images are applied by bumping the pin after review. Documented patch management
   process Regular vulnerability scanning
5. Malware Protection Current anti-malware software on all devices Automated definition updates
   enabled Regular scheduled scans configured Real-time protection active
