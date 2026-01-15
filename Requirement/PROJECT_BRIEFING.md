# Project Briefing

## Overview
- Goal: Build a web-based prototype that helps 5-9 year-olds practice and grow their English vocabulary with child-safe, AI-generated guidance.
- Audience: Young learners, with parents/teachers configuring word lists; mentors evaluating progress through staged submissions.
- Problem: Kids struggle to practice consistently; parents may lack time or confidence; enrichment options are costly; existing tools are static and limited.
- Scope: Stage 1 focuses on text-based vocabulary practice using a default list plus optional parent-provided words (typed/pasted/CSV). Uses a bounded LLM (Gemini, school-provided) to generate simple definitions/examples/quiz items. Web UI with a clear practice flow; no complex personalization in this phase.

## Success Criteria
- Proposal clearly states problem, user needs, chosen AI service (Gemini), integration plan, and evaluation plan (recall accuracy, engagement, qualitative feedback).
- Prototype delivers vocab practice with default and custom lists; AI or deterministic fallback always returns definition/example/quiz with a validated structure.
- User flow covers: select vocab set -> present practice items -> child interacts -> AI provides guidance -> session ends.
- Milestone and final reports (<8 pages for milestone) articulate business problem, architecture, integration results, and design choices; final report includes deployment details.
- Presentation demonstrates the working prototype and individual contributions, with clear metrics and outcomes.

## Constraints
- Timeline: Four stages - Proposal, Milestone Report, Final Report, Final Presentation (dates per course schedule).
- Budget/API limits: Use school-provided Gemini; other AI costs are not reimbursed. Keep prompts concise and usage minimal.
- Platforms: Web (Streamlit prototype) targeting desktop/tablet/mobile browsers.
- Data/Privacy: Child-safe content only; sanitize inputs; avoid storing PII beyond child name; keep outputs age-appropriate.

## Milestones
- Stage 1: Project Proposal - problem definition, AI service selection/justification, integration scope, evaluation plan.
- Stage 2: Milestone Report - progress update, design decisions, integration results; concise draft of final report (optional short demo video).
- Stage 3: Final Report - effectiveness, completeness, and deployment details.
- Stage 4: Final Presentation - demo, highlight individual contributions, methods, results.
- Feature build checkpoints: UI + default/custom vocab flow; LLM generation + fallback; validated schema; basic metrics for recall/engagement.

## Risks & Mitigations
- Risk: API unavailability/quota limits -> Mitigation: deterministic fallback exercises; cache and retry strategy.
- Risk: Unsafe or off-topic model output -> Mitigation: strict, child-safe prompts; JSON validation; topic filtering; input sanitization.
- Risk: Scope creep vs timeline -> Mitigation: keep Phase 1 to vocabulary-only, defer advanced personalization.
- Risk: Limited evaluation data -> Mitigation: small controlled tests; clearly state limitations and future evaluation plans.

## Open Questions
- Exact due dates and submission formats for each stage?
- Backup model or offline mode if Gemini is unavailable?
- Where to host and persist progress data for demos (local file vs managed DB)?
- Are pronunciation/spelling features required in this term or deferred to future work?
- Accessibility and localization expectations (e.g., captions, multiple languages)?