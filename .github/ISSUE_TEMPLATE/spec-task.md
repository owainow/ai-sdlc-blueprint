---
name: "Spec Task"
about: "A task generated from a spec-kit specification"
labels: ["task", "speckit"]
---

## Task: {{ TASK_ID }}

**Spec:** {{ SPEC_NAME }}
**Priority:** {{ PRIORITY }}
**Estimate:** {{ ESTIMATE }}
**Dependencies:** {{ DEPENDENCIES }}

## Description

{{ DESCRIPTION }}

## Acceptance Criteria

{{ ACCEPTANCE_CRITERIA }}

## Files to Modify

{{ FILES }}

## Functional Requirement

{{ FR_REFERENCE }}

## Implementation Notes

- Read the full spec at `specs/{{ SPEC_DIR }}/requirements.md`
- Follow the plan at `specs/{{ SPEC_DIR }}/plan.md`
- Adhere to the constitution at `.specify/constitution.md`
- Write tests alongside implementation
- Run the full test suite before marking complete
