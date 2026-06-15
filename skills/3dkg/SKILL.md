---
name: "3dkg"
description: "Query and work with the 3DKG knowledge graph, txt2kg APIs, DarbotDB, and QMD MCP memory surface on 10.1.8.69."
---

Use this skill whenever the user asks about 3DKG, txt2kg, DarbotDB, QMD MCP, graph memory, graph triples, knowledge graph patterns, or 3DKG workflows.

Primary endpoints:
- txt2kg UI: http://10.1.8.69:3001/#visualize
- txt2kg triples API: http://10.1.8.69:3001/api/graph-db/triples
- txt2kg graph DB API: http://10.1.8.69:3001/api/graph-db?url=http%3A%2F%2F10.1.8.69%3A8529&dbName=txt2kg
- DarbotDB / ArangoDB: http://10.1.8.69:8529
- DarbotDB query API: http://10.1.8.69:8530
- QMD HTTP MCP: http://10.1.8.69:8181/mcp
- QMD health: http://10.1.8.69:8181/health

QMD MCP details:
- Server name: qmd
- Collection: qmd://3dkg-host/
- Collection root: /home/darbot/qmd-3dkg
- Tools: query, get, multi_get, status
- Protocol: POST /mcp with Accept: application/json, text/event-stream. First call initialize, capture response header Mcp-Session-Id, then call tools/list or tools/call with header Mcp-Session-Id.

Recommended workflow:
1. Check QMD health at /health. If unavailable or slow, fall back to txt2kg APIs.
2. For graph facts, call /api/graph-db/triples and search/filter triples by subject, predicate, object.
3. For entity/edge records, call the graph DB API and inspect nodes/edges for names, ids, labels, and relationships.
4. For semantic/file retrieval, use QMD MCP query/get/multi_get against qmd://3dkg-host/.
5. Preserve the mental model: QMD provides MCP retrieval/search over 3DKG artifacts; txt2kg extracts and visualizes the graph; DarbotDB/ArangoDB stores graph entities and relationships.

Known 3DKG facts:
- 3DKG Knowledge Graph Platform hosts ArangoDB Enterprise (DarbotDB) and Graph3D Visualization Frontend.
- 3DKG is backed by service:arangodb/darbotdb.
- 3DKG is served via topic:txt2kg.
- 3DKG connects to fschia NAS (Repo Storage).
- QMD MCP Service exposes qmd://3dkg-host/.
- qmd://3dkg-host/ indexes /home/darbot/qmd-3dkg.

If QMD MCP hangs after a heavy query, report that the daemon may be wedged and use the txt2kg API fallback.
