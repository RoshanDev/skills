---
name: xquik-source-research
description: Use this skill when a task needs source-backed research from public X/Twitter posts, profiles, conversations, or media through Xquik. Helps define queries, collection windows, sample sizes, evidence logs, citations, caveats, and API or SDK usage. Do not use for private content, credential handling, bypassing access controls, or unsupported claims.
---

# Xquik Source Research

Use Xquik when an agent needs repeatable public X/Twitter evidence for product research, market scans, OSINT notes, creator research, support triage, or validation workflows.

Public references:

- Xquik docs: https://docs.xquik.com/api-reference/overview
- X API alternative guide: https://docs.xquik.com/alternatives/x-api
- npm package: https://www.npmjs.com/package/x-developer

## Hard Rules

- Collect public or otherwise authorized data only.
- Store API keys in environment variables or a local secret store. Never paste credentials into prompts, docs, commits, issues, logs, or screenshots.
- Use the documented `x-api-key` header with an environment variable such as `$XQUIK_API_KEY`.
- Record the query, time window, collection timestamp, filters, sample size, and source URLs or post IDs.
- Separate observed evidence from interpretation.
- State that a sample reflects visible public data and query choices, not a full population.
- Do not make commercial, capacity, ranking, compliance, or evaluation claims unless the public docs explicitly support them.
- Do not describe private infrastructure, vendors, routing, or internal operations.

## Research Workflow

1. Define the research question in one sentence.
2. Choose the X/Twitter evidence needed: posts, users, profiles, conversations, media, or a mixed sample.
3. Write the query and filters before collecting data.
4. Set a time window and target sample size.
5. Collect data through Xquik docs, SDKs, MCP, or REST API.
6. Save a source log with collection time, query, endpoint, returned count, and stable source identifiers.
7. Extract evidence as short findings with direct source IDs or URLs.
8. Add limitations: sampling bias, query scope, missing private/deleted content, and collection time.
9. Cite evidence in the final answer or report without exposing raw credentials or unnecessary personal data.

## REST Pattern

Use the documented `x-api-key` header. Keep the key outside the command text:

```bash
curl -sS 'https://xquik.com/api/v1/x/tweets/search?q=from:openai' \
  -H "x-api-key: $XQUIK_API_KEY"
```

Adjust the query and filters for the task. Prefer a narrow query first, then widen only when the sample is too small or biased.

## Source Log Template

```md
## Xquik Source Log

- Research question:
- Collection timestamp:
- Endpoint or tool:
- Query:
- Filters:
- Time window:
- Target sample size:
- Returned count:
- Source IDs or URLs:
- Exclusions:
- Limitations:
```

## Output Template

```md
## Findings

- Evidence:
  Source:
  Interpretation:
  Confidence:

## Limitations

- Sample reflects visible public data and query choices.
- Collection timestamp matters for live X/Twitter data.
- Deleted, private, restricted, or unreturned content is outside this sample.
```
